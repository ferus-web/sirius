## Implementation of the Zygote process (also called a fork server)
## This process is responsible for forking itself to launch child browser processes.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[posix, strformat]
import
  components/synapse/[decoder, types, transport/socketpairs],
  components/synapse/descriptors/[master, zygote],
  components/os/threads,
  components/impure/nix
import pkg/[chronicles, results, shakar, url]
import ./[renderer, types]

when defined(linux):
  import components/sandbox/linux/[init]

logScope:
  topics = "webview/zygote"

proc launchRendererProcess(channel: int32, params: WebViewOpts) =
  let webRenderer = initRenderer(channel, params)
  webRenderer.loadPage(parseURL("sirius:new")) # TODO: Can we not do this?
  quit(webRenderer.loop())

proc spawnChildProcess(
    client: Client, master: int32, msg: Message[ZygoteOp], params: WebViewOpts
) =
  let
    processKind = &msg.argument(0, ProcessKind)
    identifier = &msg.argument(1, uint64)
    fd = &msg.fd(0)

  info "Spawning child process", kind = processKind, channel = fd

  let pid = posix.fork()
  if pid < 0:
    discard posix.close(cast[int32](fd))
    raise newException(
      Defect,
      &"Failed to fork zygote to create process {processKind} with channel {fd}: {posix.strerror(posix.errno)}",
    )
  elif pid == 0:
    discard posix.close(master)
      # The Renderer process mustn't be able to talk to the master using the Zygote's channel.
    assert(nix.prctl(nix.PR_SET_PDEATHSIG, cast[uint64](posix.SIGKILL)) == 0)
      # We want to die if our parent (the zygote) dies.

    case processKind
    of ProcessKind.Renderer:
      launchRendererProcess(cast[int32](fd), params)
    else:
      unreachable
  else:
    discard
      posix.close(cast[int32](fd)) # We don't need the channel in the zygote anymore.

    # Let the master process associate the new PID with the spawned process.
    client.processSpawned(
      identifier = identifier, pidfd = FileDescriptor(nix.pidfd_open(pid, 0))
    )

proc main*(master: int32, params: WebViewOpts) {.noReturn.} =
  ## Entry point for the process. This has to be called once we've forked from the master
  ## process itself, and needs to be given a socket file descriptor in order to talk with
  ## the master.

  info "Hello world from the zygote process!", masterComm = master

  setThreadName("Zygote")

  let client = initClient(master)

  when defined(linux):
    let sandboxInitRes = initSandboxLinuxImpl()
    assert(*sandboxInitRes, &"initSandboxLinuxImpl() failed: {sandboxInitRes.error()}")

  while client.running:
    let msgOpt = client.blockForMessage(ZygoteOp)
    if !msgOpt:
      # The master has likely exited. We should just exit our loop too.
      break

    let msg = &msgOpt
    case msg.op
    of ZygoteOp.Spawn:
      spawnChildProcess(client, master, msg, params)

  quit(QuitSuccess)
