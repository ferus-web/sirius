## Master process' IPC routines
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[strformat, posix]
import
  components/synapse/[decoder, encoder, types, transport/socketpairs],
  components/synapse/descriptors/zygote,
  components/impure/nix
import pkg/[chronicles, results, shakar]

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
  let buffer = cast[string](master.encoder.finalize())
  var
    iov = posix.IOVec(
      iov_base: cast[pointer](buffer[0].addr), iov_len: cast[uint64](buffer.len)
    )
    msg = posix.TMsgHdr(msg_iov: iov.addr, msg_iovlen: 1)

  if master.encoder.fds.len > 0:
    var ctrlBuf = newSeq[char](posix.CMSG_SPACE(cast[uint64](sizeof(int32))))
    msg.msg_control = ctrlBuf[0].addr
    msg.msg_controllen = cast[posix.SockLen](ctrlBuf.len)

    let cmsg = posix.CMSG_FIRSTHDR(msg.addr)
    cmsg.cmsg_level = SOL_SOCKET
    cmsg.cmsg_type = SCM_RIGHTS
    cmsg.cmsg_len =
      CMSG_LEN(cast[uint64](sizeof(int32))) * cast[uint64](master.encoder.fds.len)

    let fds = cast[ptr UncheckedArray[int32]](CMSG_DATA(cmsg))
    for i, fd in master.encoder.fds:
      fds[i] = fd

  if posix.sendmsg(SocketHandle(fd), msg.addr, posix.MSG_NOSIGNAL) < 1:
    return err(&"{posix.strerror(posix.errno)} (errno {posix.errno})")

  master.encoder.buffer.setLen(0)
  ok()

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

proc initMaster*(zygoteRoutine: ZygoteRoutine): Master =
  let master =
    Master(encoder: initEncoder(MaxPacketSize), decoder: initDecoder(MaxPacketSize))
  spawnZygote(master, zygoteRoutine)
  master
