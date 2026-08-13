## Master process' IPC routines
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[strformat, options, posix]
import
  components/synapse/[decoder, encoder, types, transport/socketpairs],
  components/synapse/descriptors/[renderer, zygote],
  components/impure/nix
import pkg/[chronicles, results, shakar, vmath]

proc spawnZygote*(
    master: Master, zygoteRoutine: ZygoteRoutine
) {.raises: [IPCDefect, IOError].} =
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
      # HACK: Exceptions in here reallu aren't our problem, but feel free to correct me :P
      zygoteRoutine(pair.ours())

    stderr.write(
      "zygote: Invariant: ZygoteRoutine returned back to spawnZygote. Your implementation is faulty. :("
    )
    nix.abort()
  else:
    info "Created Zygote process successfully"

    discard posix.close(pair.theirs()) # We don't need the zygote=>master fd.
    master.zygote = Process(fd: pair.ours(), kind: ProcessKind.Zygote)

proc send*(master: Master, fd: int32): Result[void, string] =
  let res = send(fd, master.encoder.fds, master.encoder.finalize())

  master.encoder.buffer.setLen(0)
  master.encoder.fds.setLen(0)
  res

proc spawn*(master: Master, tab: uint32, kind: static ProcessKind, socks: SocketPair) =
  static:
    assert(kind != ProcessKind.Zygote, "Use `spawnZygote()`, not this!")

  # Spawn
  # Argument 1: ProcessKind
  # Argument 2: FD (the one that the process will use to talk to the master)
  master.encoder.encode(ZygoteOp.Spawn)
  master.encoder.push(kind)
  master.encoder.push(FileDescriptor(socks.theirs()))

  assert *master.send(master.zygote.fd)

  master.tabs[tab].processes &= Process(fd: socks.ours(), kind: kind)

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

proc drawFrame*(master: Master, process: Process) =
  assert(process.kind == ProcessKind.Renderer)

  # drawFrame
  # (no arguments)
  master.encoder.encode(RenderOp.DrawFrame)

  assert *master.send(process.fd)

proc resizeRenderTarget*(master: Master, process: Process, dims: vmath.IVec2) =
  assert(process.kind == ProcessKind.Renderer)

  # resizeRenderTarget
  # Argument 1: vmath.IVec2
  master.encoder.encode(RenderOp.ResizeRenderTarget)
  master.encoder.push(dims)

  assert *master.send(process.fd)

proc initMaster*(zygoteRoutine: ZygoteRoutine): Master =
  let master =
    Master(encoder: initEncoder(MaxPacketSize), decoder: initDecoder(MaxPacketSize))
  spawnZygote(master, zygoteRoutine)
  master
