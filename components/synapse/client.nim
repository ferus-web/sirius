## Routines for clients
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/posix
import components/synapse/[encoder, transport/socketpairs, types]
import pkg/[results]

proc send*(client: Client): Result[void, string] =
  let res = send(client.fd, client.encoder.fds, client.encoder.finalize())

  client.encoder.buffer.setLen(0)
  client.encoder.fds.setLen(0)
  res
