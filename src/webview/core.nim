## Core routines for `WebView`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, posix]
import
  components/synapse/[encoder, decoder, master, types, transport/socketpairs],
  components/synapse/descriptors/[master],
  components/css/types,
  components/impure/nix
import pkg/[chronicles, url, vmath, results, shakar]
import ../webview/[zygote], ./[types]

logScope:
  topics = "webview/core"

proc attachPollingForTab(view: WebView, id: TabID) =
  let rendererFd = (&view.master.tabs[cast[uint32](id)].renderer()).fd

  var event = nix.EpollEvent(
    events: nix.EPOLLIN or nix.EPOLLHUP, data: nix.EpollData(fd: rendererFd)
  )

  assert(
    nix.epoll_ctl(view.pollingFd, nix.EPOLL_CTL_ADD, rendererFd, event.addr) == 0,
    "Failed to attach epoll listener to IPC channel",
  )

proc createTab*(view: WebView): TabID =
  let tabId = cast[uint32](view.master.tabs.len)
  view.master.tabs &= Tab()

  let sockPair = createSocketPair()
  assert(*sockPair, sockPair.error())

  view.master.spawn(tabId, ProcessKind.Renderer, &sockPair)
  view.attachPollingForTab(cast[TabID](tabId))

  cast[TabID](tabId)

{.push inline.}
proc loadURL*(view: WebView, id: TabID, target: url.URL) =
  view.master.gotoURL(id, target)

proc requestFrame*(view: WebView, id: TabID) =
  view.master.drawFrame(&view.master.tabs[cast[uint32](id)].renderer())

proc resizeRenderTarget*(view: WebView, id: TabID, dims: vmath.IVec2) =
  view.master.resizeRenderTarget(&view.master.tabs[cast[uint32](id)].renderer(), dims)

proc scroll*(view: WebView, id: TabID, velocity: vmath.Vec2) =
  view.master.scrollViewport(cast[uint32](id), velocity)

proc moveCursor*(view: WebView, id: TabID, position: vmath.Vec2) =
  view.master.cursorMotion(cast[uint32](id), position)

proc click*(view: WebView, id: TabID) =
  view.master.cursorClick(cast[uint32](id))

proc pressKey*(view: WebView, id: TabID, key, keycode: string, repeat: bool) =
  view.master.pressKey(cast[uint32](id), key, keycode, repeat)

{.pop.}

proc cleanupDeadProcess(view: WebView, tab: TabID, process: Process) =
  discard nix.epoll_ctl(view.pollingFd, nix.EPOLL_CTL_DEL, process.fd, nil)
  discard posix.close(process.fd)

  if view.callbacks.onProcessFault != nil:
    view.callbacks.onProcessFault(view, tab, process)

proc handleIPCMessage(view: WebView, events: uint32, fd: int32) =
  let assoc = view.master.findAssociatedClientByFd(fd)
  if !assoc:
    warn "Received message from non-associated channel", chan = fd
    return

  let (tab, process) = &assoc

  if (events and nix.EPOLLHUP) != 0'u32:
    warn "Process channel sent hang-up", tab = tab, kind = process.kind
    cleanupDeadProcess(view, cast[TabID](tab), process)
    return

  let msgOpt = view.master.blockForMessage(MasterOp, fd = some(fd))
  if !msgOpt:
    warn "Received no message, did this process die?", sender = fd
    return

  let
    msg = &msgOpt
    tabId = cast[TabID](tab)

  # TODO: validate arguments
  case msg.op
  of MasterOp.FrameDrawn:
    if view.callbacks.onFrameDrawn != nil:
      view.callbacks.onFrameDrawn(view, tabId)
  of MasterOp.TargetResized:
    view.bufferStride = &msg.argument(1, uint32)

    if view.callbacks.onResize != nil:
      view.callbacks.onResize(view, tabId, &msg.argument(0, vmath.IVec2))
  of MasterOp.SetPageTitle:
    if view.callbacks.onPageTitleChange != nil:
      view.callbacks.onPageTitleChange(view, tabId, &msg.argument(0, string))
  of MasterOp.SetPCursorShape:
    if view.callbacks.onSetCursorShape != nil:
      view.callbacks.onSetCursorShape(view, tabId, &msg.argument(0, CursorPredefined))
  of MasterOp.UseGraphicsFD:
    let dmaFd = &msg.fd(0)
    if dmaFd < 0:
      warn "Renderer returned invalid graphics buffer fd", tab = tab, fd = dmaFd
      return

    if view.bufferFd >= 0'i32:
      discard posix.close(view.bufferFd)

    view.bufferFd = dmaFd
    echo "use graphics fd " & $view.bufferFd
    if view.callbacks.onReconstruct != nil:
      view.callbacks.onReconstruct(view, tabId)
  of MasterOp.AlertMessage:
    if view.callbacks.onAlert != nil:
      view.callbacks.onAlert(view, tabId, msg.argument(0, string))

proc step*(view: WebView) =
  var ipcEvent: nix.EpollEvent
  let ipcEventCount = nix.epoll_wait(
    view.pollingFd,
    ipcEvent.addr,
    maxevents = cast[int32](view.master.tabs.len),
    timeout = 6'i32,
  )

  if ipcEventCount > 0:
    handleIPCMessage(view, ipcEvent.events, ipcEvent.data.fd)

proc initWebView*(opts: WebViewOpts): WebView =
  # TODO: Make WebViewOpts work again
  WebView(
    master: initMaster(zygote.main),
    pollingFd: nix.epoll_create1(0),
    bufferFd: -1'i32,
    opts: opts,
  )
