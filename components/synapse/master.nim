## Master process' IPC routines
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[strformat, options, posix]
import
  components/synapse/[decoder, encoder, types, transport/socketpairs],
  components/synapse/descriptors/[renderer, zygote],
  components/impure/nix
import pkg/[chronicles, results, shakar, vmath, url]

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
      # TODO: Can we clear the call stack prior to this and treat it like our entrypoint?
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

  discard posix.close(socks.theirs())

  let ourFd = socks.ours()
  let flags = posix.fcntl(ourFd, posix.F_GETFL, 0'i32)
  assert(posix.fcntl(ourFd, posix.F_SETFL, flags or posix.O_NONBLOCK) >= 0'i32)

  master.tabs[tab].processes &= Process(fd: ourFd, kind: kind)

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

proc gotoURL*(master: Master, tab: uint32, target: url.URL) =
  let process = &master.tabs[tab].renderer()

  # gotoURL
  # Argument 1: string
  master.encoder.encode(RenderOp.GotoURL)
  master.encoder.push(target.serialize())

  assert *master.send(process.fd)

proc scrollViewport*(master: Master, tab: uint32, velocity: vmath.Vec2) =
  let process = &master.tabs[tab].renderer()

  # viewportScroll
  # Argument 1: vmath.Vec2
  master.encoder.encode(RenderOp.ViewportScroll)
  master.encoder.push(velocity)

  discard master.send(process.fd)

proc cursorMotion*(master: Master, tab: uint32, position: vmath.Vec2) =
  let process = &master.tabs[tab].renderer()

  # cursorMotion
  # Argument 1: vmath.Vec2
  master.encoder.encode(RenderOp.CursorMotion)
  master.encoder.push(position)

  discard master.send(process.fd)

proc cursorClick*(master: Master, tab: uint32) =
  let process = &master.tabs[tab].renderer()

  # cursorClick
  master.encoder.encode(RenderOp.CursorClick)

  discard master.send(process.fd)

func findAssociatedClientByFd*(
    master: Master, fd: int32
): Option[tuple[tab: uint32, process: Process]] =
  for i, tab in master.tabs:
    for process in tab.processes:
      if process.fd == fd:
        return some((tab: cast[uint32](i), process: process))

proc pressKey*(
    master: Master, tab: uint32, key: string, keycode: string, repeat: bool
) =
  let process = &master.tabs[tab].renderer()

  # keyPressed
  # TODO: document this one
  master.encoder.encode(RenderOp.KeyPressed)
  master.encoder.push(key)
  master.encoder.push(keycode)
  master.encoder.push(repeat.int64)

  discard master.send(process.fd)

proc initMaster*(zygoteRoutine: ZygoteRoutine): Master =
  let master =
    Master(encoder: initEncoder(MaxPacketSize), decoder: initDecoder(MaxPacketSize))
  spawnZygote(master, zygoteRoutine)
  master
