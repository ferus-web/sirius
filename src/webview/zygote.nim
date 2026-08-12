## Implementation of the Zygote process (also called a fork server)
## This process is responsible for forking itself to launch child browser processes.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[posix, strformat]
import
  components/synapse/[decoder, types, transport/socketpairs],
  components/synapse/descriptors/zygote,
  components/os/threads
import pkg/[chronicles, shakar]
import ./[renderer, types]

logScope:
  topics = "webview/zygote"

proc launchRendererProcess(channel: int32) =
  let webRenderer = initRenderer(channel)
  webRenderer.loadPage("sirius:new")
  quit(webRenderer.loop())

proc spawnChildProcess(master: int32, msg: Message[ZygoteOp]) =
  let
    processKind = &msg.argument(0, ProcessKind)
    fd = &msg.fd(0)

  info "Spawning child process", kind = processKind, channel = fd

  let pid = posix.fork()
  if pid < 0:
    raise newException(
      Defect,
      &"Failed to fork zygote to create process {processKind} with channel {fd}: {posix.strerror(posix.errno)}",
    )
  elif pid == 0:
    discard
      posix.close(master) # The Renderer process mustn't be able to talk to the master.

    case processKind
    of ProcessKind.Renderer:
      launchRendererProcess(fd)
    else:
      unreachable
  else:
    discard posix.close(fd) # We don't need the channel in the zygote anymore.

proc main*(master: int32) {.noReturn.} =
  ## Entry point for the process. This has to be called once we've forked from the master
  ## process itself, and needs to be given a socket file descriptor in order to talk with
  ## the master.

  info "Hello world from the zygote process!", masterComm = master

  setThreadName("Zygote")

  let client = initClient(master)
  while client.running:
    let msgOpt = client.blockForMessage(ZygoteOp)
    if !msgOpt:
      warn "Cannot decode data received, ignoring."
      continue

    let msg = &msgOpt
    case msg.op
    of ZygoteOp.Spawn:
      spawnChildProcess(master, msg)

  quit(QuitSuccess)
