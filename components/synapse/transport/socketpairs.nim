## `socketpair(2)`-based IPC transport
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[posix, strformat]
import pkg/[chronicles, results, shakar]

logScope:
  topics = "ipc/transport/socketpairs"

type
  IPCDefect* = object of Defect
    ## Unrecoverable IPC initialization errors (atleast, for now)

  SocketPair = array[2, int32]

proc createSocketPair(): Result[SocketPair, string] {.sideEffect.} =
  var fds: SocketPair

  if posix.socketpair(posix.AF_UNIX, posix.SOCK_SEQPACKET or posix.SOCK_CLOEXEC, 0, fds) !=
      0:
    return err($posix.strerror(posix.errno))

  info "Created socket pair", master = fds[0], other = fds[1]
  ok(ensureMove(fds))

proc spawnZygote(master: Master) {.raises: [IPCDefect].} =
  info "Spawning zygote process"
  let pairOpt = createSocketPair()
  if !pairOpt:
    raise newException(
      IPCDefect, &"Cannot create socket pair for master=>zygote IPC: {pairOpt.error()}"
    )

  let pair = &pairOpt

  debug "Forking to create Zygote"
  let pid = posix.fork()
  if pid < 0:
    raise newException(
      IPCDefect,
      &"Failed to fork to create zygote process: {posix.strerror(posix.errno)}",
    )
  elif pid == 0:
    echo "im the zygote :D"
    quit(0)
  else:
    info "Created Zygote process successfully"
    master.zygote = Process(fd: pair[0], kind: ProcessKind.Zygote)

proc initMaster*(): Master =
  let master = Master()
  spawnZygote(master)
