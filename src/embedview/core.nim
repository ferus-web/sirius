## Core routines for `EmbedView`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options]
import
  components/synapse/[encoder, decoder, master, types, transport/socketpairs],
  components/synapse/descriptors/[master],
  components/css/types,
  components/impure/nix
import pkg/[chronicles, url, vmath, results, shakar]
import ../webview/[zygote], ./[types]

logScope:
  topics = "embedview/core"

proc attachPollingForTab(view: EmbedView, id: TabID) =
  let rendererFd = (&view.master.tabs[cast[uint32](id)].renderer()).fd

  var event = nix.EpollEvent(
    events: nix.EPOLLIN or nix.EPOLLHUP, data: nix.EpollData(fd: rendererFd)
  )

  assert(
    nix.epoll_ctl(view.pollingFd, nix.EPOLL_CTL_ADD, rendererFd, event.addr) == 0,
    "Failed to attach epoll listener to IPC channel",
  )

proc createTab*(view: EmbedView): TabID =
  let tabId = cast[uint32](view.master.tabs.len)
  view.master.tabs &= Tab()

  let sockPair = createSocketPair()
  assert(*sockPair, sockPair.error())

  view.master.spawn(tabId, ProcessKind.Renderer, &sockPair)
  view.attachPollingForTab(cast[TabID](tabId))

  cast[TabID](tabId)

{.push inline.}
proc loadURL*(view: EmbedView, id: TabID, target: url.URL) =
  view.master.gotoURL(id, target)

proc requestFrame*(view: EmbedView, id: TabID) =
  view.master.drawFrame(&view.master.tabs[cast[uint32](id)].renderer())

{.pop.}

proc handleIPCMessage(view: EmbedView, fd: int32) =
  let assoc = view.master.findAssociatedClientByFd(fd)
  if !assoc:
    warn "Received message from non-associated channel", chan = fd
    return

  let msgOpt = view.master.blockForMessage(MasterOp, fd = some(fd))
  if !msgOpt:
    warn "Received no message, did this process die?", sender = fd
    return

  let
    (tab, process) = &assoc
    msg = &msgOpt
    tabId = cast[TabID](tab)

  # TODO: validate arguments
  case msg.op
  of MasterOp.FrameDrawn:
    if view.callbacks.onFrameDrawn != nil:
      view.callbacks.onFrameDrawn(view, tabId, view.bufferFd)
  of MasterOp.TargetResized:
    view.bufferStride = &msg.argument(1, uint32)

    if view.callbacks.onResize != nil:
      view.callbacks.onResize(view, &msg.argument(0, vmath.IVec2))
  of MasterOp.SetPageTitle:
    if view.callbacks.onPageTitleChange != nil:
      view.callbacks.onPageTitleChange(view, tabId, &msg.argument(0, string))
  of MasterOp.SetPCursorShape:
    if view.callbacks.onSetCursorShape != nil:
      view.callbacks.onSetCursorShape(view, &msg.argument(0, CursorPredefined))
  of MasterOp.UseGraphicsFD:
    view.bufferFd = &msg.fd(0)

proc step*(view: EmbedView) =
  var ipcEvent: nix.EpollEvent
  let ipcEventCount = nix.epoll_wait(
    view.pollingFd,
    ipcEvent.addr,
    maxevents = cast[int32](view.master.tabs.len),
    timeout = 6'i32,
  )

  if ipcEventCount > 0:
    handleIPCMessage(view, ipcEvent.data.fd)

proc initEmbedView*(): EmbedView =
  EmbedView(master: initMaster(zygote.main), pollingFd: nix.epoll_create1(0))
