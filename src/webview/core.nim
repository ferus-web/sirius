## Core routines for `WebView`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[importutils, options, posix, strformat, tables]
import
  components/synapse/[encoder, decoder, master, reporting, types, transport/socketpairs],
  components/synapse/descriptors/[master, renderer],
  components/css/types,
  components/impure/nix,
  components/os/event_loop
import pkg/[chronicles, url, vmath, results, shakar]
import ../webview/[zygote], ./[types]

logScope:
  topics = "webview/core"

proc attachPollingForTab(view: WebView, id: TabID) =
  let rendererTrigger = (&view.master.tabs[cast[uint32](id)].renderer()).trig

  let rendererRegisterRes =
    view.loop.register(rendererTrigger, modes = {EventMode.Input, EventMode.Hangup})
  assert(*rendererRegisterRes, &"{rendererRegisterRes.error()}")

proc createTab*(view: WebView): TabID =
  let tabId = cast[TabID](view.master.tabs.len)
  view.master.tabs &= Tab()

  let sockPair = createSocketPair()
  assert(*sockPair, sockPair.error())

  view.master.spawn(cast[uint32](tabId), ProcessKind.Renderer, &sockPair)
  view.attachPollingForTab(tabId)

  tabId

{.push inline.}
proc loadURL*(view: WebView, id: TabID, target: url.URL) =
  view.master.gotoURL(id, target)

proc requestFrame*(view: WebView, id: TabID) =
  view.master.drawFrame(cast[uint32](id))

proc resizeRenderTarget*(view: WebView, id: TabID, dims: vmath.IVec2) =
  view.master.resizeRenderTarget(cast[uint32](id), dims)

proc scroll*(view: WebView, id: TabID, velocity: vmath.Vec2) =
  view.master.viewportScroll(cast[uint32](id), velocity)

proc moveCursor*(view: WebView, id: TabID, position: vmath.Vec2) =
  view.master.cursorMotion(cast[uint32](id), position)

proc click*(view: WebView, id: TabID) =
  view.master.cursorClick(cast[uint32](id))

proc pressKey*(view: WebView, id: TabID, key, keycode: string, repeat: bool) =
  view.master.keyPressed(cast[uint32](id), key, keycode, repeat)

proc requestGraphicsFd*(view: WebView, id: TabID) =
  view.master.sendGraphicsFd(cast[uint32](id))

proc clipboardWriteAck*(view: WebView, id: TabID, promiseId: uint32) =
  view.master.clipboardWriteAck(cast[uint32](id), promiseId)

proc clipboardReadAck*(view: WebView, id: TabID, promiseId: uint32, data: string) =
  view.master.clipboardReadAck(cast[uint32](id), promiseId, data)

proc clipboardWriteNack*(view: WebView, id: TabID, promiseId: uint32) =
  view.master.clipboardWriteNack(cast[uint32](id), promiseId)

proc clipboardReadNack*(view: WebView, id: TabID, promiseId: uint32) =
  view.master.clipboardReadNack(cast[uint32](id), promiseId)

proc exit*(view: WebView, id: TabID) =
  view.master.exit(cast[uint32](id))
  discard view.loop.unregister((&view.master.tabs[cast[uint32](id)].renderer()).trig)

{.pop.}

proc cleanupDeadProcess(view: WebView, tab: TabID, process: Process) =
  discard view.loop.unregister(process.trig)

  if view.callbacks.onProcessFault != nil:
    view.callbacks.onProcessFault(view, tab, process)

proc handleZygoteIPCMessage(view: WebView, event: Event) =
  let msgOpt = view.master.blockForMessage(MasterOp, fd = some(event.trigger.fd))
  if !msgOpt:
    warn "Received no message, did this process die?", sender = event.trigger.fd
    return

  let
    process = view.master.zygote
    msg = &msgOpt

  case msg.op
  of MasterOp.ProcessSpawned:
    if process.kind != ProcessKind.Zygote:
      view.master.reportBadMessage(
        view.loop, process,
        "A process that is not a Zygote sent a ProcessSpawned message!",
      )

    let paramsOpt = msg.params(ProcessSpawnedParams)
    if !paramsOpt:
      echo "error @1: " & paramsOpt.error()
      view.master.reportBadMessage(
        view.loop, process, "Cannot decode parameters for ProcessSpawned"
      )

    let params = &paramsOpt
    var found = false
    for tab in view.master.tabs:
      for procs in tab.processes:
        when defined(linux):
          if cast[uint64](hash(procs)) == params.identifier:
            found = true
            procs.id = some(cast[nix.Pidfd](params.pidfd))
            break
        else:
          {.error: "Implement ProcessSpawned PID association for your platform".}

    if not found:
      view.master.reportBadMessage(
        view.loop, process, "Could not associate PID to process via ProcessSpawned"
      )
  else:
    view.master.reportBadMessage(view.loop, process, "Zygote sent an unintended opcode")

proc handleIPCMessage(view: WebView, event: Event) =
  privateAccess(WebView)

  if event.trigger == view.master.zygote.trig:
    # This is a message from the Zygote.
    handleZygoteIPCMessage(view, event)
    return

  let assoc = view.master.findAssociatedClientByFd(event.trigger.fd)
  if !assoc:
    warn "Received message from non-associated channel", chan = event.trigger.fd
    return

  let (tab, process) = &assoc

  if EventMode.Hangup in event.modes:
    warn "Process channel sent hang-up", tab = tab, kind = process.kind
    cleanupDeadProcess(view, cast[TabID](tab), process)
    return

  let msgOpt = view.master.blockForMessage(MasterOp, fd = some(event.trigger.fd))
  if !msgOpt:
    warn "Received no message, did this process die?", sender = event.trigger.fd
    return

  let
    msg = &msgOpt
    tabId = cast[TabID](tab)

  # TODO: Migrate all of these to use the validating parameter decoder
  case msg.op
  of MasterOp.FrameDrawn:
    if view.callbacks.onFrameDrawn != nil:
      view.callbacks.onFrameDrawn(view, tabId)
  of MasterOp.TargetResized:
    let paramsOpt = msg.params(TargetResizedParams)
    if !paramsOpt:
      view.master.reportBadMessage(view.loop, process, paramsOpt.error())

    let params = &paramsOpt
    view.bufferStride = params.stride

    if view.callbacks.onResize != nil:
      view.callbacks.onResize(view, tabId, params.renderSize)
  of MasterOp.SetPageTitle:
    if view.callbacks.onPageTitleChange != nil:
      view.callbacks.onPageTitleChange(view, tabId, &msg.argument(0, string))
  of MasterOp.SetPCursorShape:
    if view.callbacks.onSetCursorShape != nil:
      view.callbacks.onSetCursorShape(view, tabId, &msg.argument(0, CursorPredefined))
  of MasterOp.UseGraphicsFD:
    let dmaFd = &msg.fd(0)
    if cast[int32](dmaFd) < 0:
      warn "Renderer returned invalid graphics buffer fd", tab = tab, fd = dmaFd
      return

    if view.bufferFd >= 0'i32:
      discard posix.close(view.bufferFd)

    # debugEcho "tab " & $tab & " uses buffer " & $dmaFd
    view.bufferFd = cast[int32](dmaFd)
    if view.callbacks.onReconstruct != nil:
      view.callbacks.onReconstruct(view, tabId)
  of MasterOp.AlertMessage:
    let paramsOpt = msg.params(AlertMessageParams)
    if !paramsOpt:
      view.master.reportBadMessage(view.loop, process, paramsOpt.error())

    let params = &paramsOpt
    if view.callbacks.onAlert != nil:
      view.callbacks.onAlert(view, tabId, params.text)
  of MasterOp.UpdateNavigation:
    let navigationUrl = &msg.argument(0, URL)
    view.master.tabs[tab].url = navigationUrl

    # debugecho "update nav: " & $view.master.tabs[tab].url

    if view.callbacks.onNavigationUpdate != nil:
      view.callbacks.onNavigationUpdate(view, tabId, navigationUrl)
  of MasterOp.ClipboardWriteText:
    let
      textData = &msg.argument(0, string)
      promiseId = &msg.argument(1, uint32)

    if view.callbacks.onClipboardWriteText != nil:
      view.callbacks.onClipboardWriteText(view, tabId, textData, promiseId)
  of MasterOp.UpdateStatusBar:
    let statusText = msg.argument(0, string)

    if view.callbacks.onStatusBarUpdate != nil:
      view.callbacks.onStatusBarUpdate(view, tabId, statusText)
  of MasterOp.CallEmbedBinding:
    let name = &msg.argument(0, string)
    view.routedFns[name](view, msg)
  of MasterOp.ClipboardReadText:
    let promiseId = &msg.argument(0, uint32)

    if view.callbacks.onClipboardReadText != nil:
      view.callbacks.onClipboardReadText(view, tabId, promiseId)
  of MasterOp.ProcessSpawned:
    view.master.reportBadMessage(
      view.loop, process, "Non-Zygote processes cannot send ProcessSpawned signal!"
    )

proc step*(view: WebView) =
  let events = view.loop.wait()
  if !events:
    warn "EventLoop::wait() failed!", msg = events.error()
    return

  for event in &events:
    assert(event.trigger.kind == TriggerKind.IPC)
      # None of the other triggers should apply to the UI process.
    view.handleIPCMessage(event)

proc initWebView*(opts: WebViewOpts): WebView =
  let
    loop = initEventLoop()
    master = initMaster(zygote.main, params = opts)

  assert(*loop, &"{loop.error()}")
  assert(*register(&loop, master.zygote.trig, {EventMode.Input}))
    # TODO: Maybe we can handle hangups too, if the zygote ever somehow crashes.

  WebView(master: master, loop: &loop, bufferFd: -1'i32, opts: opts)
