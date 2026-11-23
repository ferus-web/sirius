## Master process' IPC routines
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[strformat, options, posix]
import
  components/synapse/[decoder, encoder, types, transport/socketpairs],
  components/synapse/descriptors/[zygote],
  components/os/event_loop,
  components/impure/nix
import pkg/[chronicles, results, shakar, vmath, url]

proc spawnZygote*[T: object](
    master: Master, zygoteRoutine: ZygoteRoutine[T], params: T
) {.raises: [IOError].} =
  info "Spawning zygote process"
  let pairOpt = createSocketPair()
  if !pairOpt:
    raise newException(
      IPCDefect, &"Cannot create socket pair for master=>zygote IPC: {pairOpt.error()}"
    )

  var pair = &pairOpt

  debug "Forking to create Zygote"
  let pid = posix.fork()
  if pid < 0:
    raise newException(
      IPCDefect,
      &"Failed to fork to create zygote process: {posix.strerror(posix.errno)}",
    )
  elif pid == 0:
    swap pair

    discard posix.close(pair.theirs()) # We don't need the master=>zygote fd.

    {.cast(raises: []).}:
      # TODO: Can we clear the call stack prior to this and treat it like our entrypoint?
      # HACK: Exceptions in here reallu aren't our problem, but feel free to correct me :P
      zygoteRoutine(pair.ours(), params)

    stderr.write(
      "zygote: Invariant: ZygoteRoutine returned back to spawnZygote. Your implementation is faulty. :(\n"
    )
    nix.abort()
  else:
    info "Created Zygote process successfully"

    discard posix.close(pair.theirs()) # We don't need the zygote=>master fd.
    master.zygote = Process(trig: ipc(pair.ours()), kind: ProcessKind.Zygote)

{.push discardable.}
proc send*(master: Master, fd: int32): Result[void, string] =
  let res = send(fd, master.encoder.fds, master.encoder.finalize())

  master.encoder.buffer.setLen(0)
  master.encoder.fds.setLen(0)
  res

proc send*(master: Master, process: Process): Result[void, string] =
  send(master, process.trig.fd)

{.pop.}

proc spawn*(master: Master, tab: uint32, kind: static ProcessKind, socks: SocketPair) =
  static:
    assert(kind != ProcessKind.Zygote, "Use `spawnZygote()`, not this!")

  let
    ourFd = socks.ours()
    process = Process(trig: ipc(ourFd), kind: kind)

  # Spawn
  # Argument 1: ProcessKind
  # Argument 2: FD (the one that the process will use to talk to the master)
  # Argument 3: Identifier (so the zygote can signal readiness back to us)
  master.encoder.encode(ZygoteOp.Spawn)
  master.encoder.push(kind)
  master.encoder.push(FileDescriptor(socks.theirs()))
  master.encoder.push(hash(process))

  assert *master.send(master.zygote.trig.fd)

  discard posix.close(socks.theirs())

  let flags = posix.fcntl(ourFd, posix.F_GETFL, 0'i32)
  assert(posix.fcntl(ourFd, posix.F_SETFL, flags or posix.O_NONBLOCK) >= 0'i32)

  master.tabs[tab].processes &= process

func renderer*(tab: Tab): Option[Process] =
  ## Get the Renderer process for this tab.
  ## This returns the first instance of `ProcessKind.Renderer` that is found.
  ## If there are multiple instances (there shouldn't, at once!), it will obviously
  ## only return the very first one.
  ##
  ## Returns an empty optional if none is found.
  for process in tab.processes:
    if process.kind == ProcessKind.Renderer:
      return some(process)

  none(Process)

func findAssociatedClientByFd*(
    master: Master, fd: int32
): Option[tuple[tab: uint32, process: Process]] =
  for i, tab in master.tabs:
    for process in tab.processes:
      if process.trig.fd == fd:
        return some((tab: cast[uint32](i), process: process))

proc initMaster*[T: object](zygoteRoutine: ZygoteRoutine, params: T): Master =
  let master =
    Master(encoder: initEncoder(MaxPacketSize), decoder: initDecoder(MaxPacketSize))
  spawnZygote(master, zygoteRoutine, params)
  master
