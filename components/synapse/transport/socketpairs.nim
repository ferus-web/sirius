## `socketpair(2)`-based IPC transport
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, posix, strformat]
import components/synapse/[decoder, encoder, types], components/impure/nix
import pkg/[chronicles, results, shakar]

logScope:
  topics = "ipc/transport/socketpairs"

const
  MaxPacketSize* = 65536 # source: trust me bro
  MaxFDs* = 2
    # We really shouldn't need more than one fd per messages that require it, much less two.

type
  IPCDefect* = object of Defect
    ## Unrecoverable IPC initialization errors (atleast, for now)

  SocketPair* = array[2, int32]

func ours*(socks: SocketPair): int32 {.inline, raises: [].} =
  socks[0]
func theirs*(socks: SocketPair): int32 {.inline, raises: [].} =
  socks[1]
func swap*(socks: var SocketPair) {.inline, raises: [].} =
  swap(socks[0], socks[1])

proc blockForMessage*[O: SomeOrdinal](
    client: Client, op: typedesc[O]
): Option[Message[O]] =
  let buffer = client.decoder.writeHandle(MaxPacketSize) # ensure the buffer is 64KB
  zeroMem(buffer, MaxPacketSize)

  var
    iov = posix.IOVec(iov_base: buffer, iov_len: MaxPacketSize)
    ctrlBuf = newString(posix.CMSG_SPACE(cast[uint64](sizeof(int32)) * MaxFDs))
    msg = posix.TMsgHdr(
      msg_iov: iov.addr,
      msg_iovlen: 1,
      msg_control: ctrlBuf[0].addr,
      msg_controllen: cast[posix.SockLen](ctrlBuf.len),
    )

  let readCount = posix.recvmsg(SocketHandle(client.fd), msg.addr, nix.MSG_CMSG_CLOEXEC)
  if readCount < 0:
    warn "Failed to read message from file descriptor",
      fd = client.fd, errno = posix.errno, message = posix.strerror(posix.errno)
    return
  elif readCount == 0:
    info "Master process seems to have exited", fd = client.fd
    client.running = false
    return

  discard client.decoder.writeHandle(cast[uint64](readCount))

  var message = client.decoder.decode(op)

  var cmsg = posix.CMSG_FIRSTHDR(msg.addr)
  while cmsg != nil:
    if cmsg.cmsg_level == posix.SOL_SOCKET and cmsg.cmsg_type == posix.SCM_RIGHTS:
      let
        payloadSize = cmsg.cmsg_len
        numFds = payloadSize div cast[uint64](sizeof(int32))
        fdList = cast[ptr UncheckedArray[int32]](posix.CMSG_DATA(cmsg))

      if *message:
        message.applyThis:
          for i in 0 ..< numFds:
            if fdList[i] == 0:
              continue

            this.fds &= fdList[i]

    cmsg = posix.CMSG_NXTHDR(msg.addr, cmsg)

  ensureMove(message)

proc createSocketPair*(): Result[SocketPair, string] {.sideEffect.} =
  var fds: SocketPair

  if posix.socketpair(posix.AF_UNIX, posix.SOCK_SEQPACKET or posix.SOCK_CLOEXEC, 0, fds) !=
      0:
    return err($posix.strerror(posix.errno))

  info "Created socket pair", master = fds.ours(), other = fds.theirs()
  ok(ensureMove(fds))

proc initClient*(master: int32): Client =
  # TODO: move this elsewhere.
  Client(
    running: true,
    fd: master,
    decoder: initDecoder(MaxPacketSize),
    encoder: initEncoder(MaxPacketSize),
  )
