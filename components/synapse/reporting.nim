## Methods to report bad messages.
##
## **Note**: This is only meant for the privileged browser process to use. Child processes are expected to ignore invalid data from the master entirely, or crash with a failed assertion at best.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import
  components/synapse/[master, types], components/os/event_loop, components/impure/nix
import pkg/[chronicles, results, shakar]

when defined(linux):
  import std/posix

logScope:
  topics = "ipc/reporting"

template reportBadMessage*(
    master: Master, loop: EventLoop, process: Process, reason: string
) =
  ## This routine is to be called when a process sends a "bad" (malformed) message over IPC.
  ##
  ## **Note**: Malformed here can mean either on the protocol or logic layers.
  warn "Reporting bad message", process = process.kind, why = reason

  # 1. Firstly, reset the decoder's state so that we do not have any leftovers from this message.
  zeroMem(master.decoder.buffer[0].addr, master.decoder.buffer.len)
  master.decoder.buffer.setLen(0)

  # 2. Immediately deregister the trigger for this process.
  if (let res = loop.unregister(process.trig); !res):
    warn "Failed to unregister malfunctioning process's trigger from event loop!",
      why = res.error()

  when defined(linux):
    # 3. Close its IPC channel file descriptor.
    discard posix.close(process.trig.fd)

  when nix.SupportsPidfd:
    # 4. Now, send the process a kill signal.
    if *process.id:
      discard nix.pidfd_send_signal(&process.id, posix.SIGKILL, nil, 0'u32)
      discard posix.close(cast[int32](&process.id))
    else:
      # Even if we cannot kill the process, atleast we ensure we can't just accidentally talk to it again.
      warn "Cannot kill process, cannot find its associated PID. Wonderful."

  # Also, interrupt control flow.
  return
