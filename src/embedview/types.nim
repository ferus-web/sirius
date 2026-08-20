## Types for Sirius' embedding subsystem
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/synapse/[types], components/css/types
import pkg/vmath

type
  TabID* = distinct uint32 # TODO: move this into the actual tab system?

  FrameDrawnCallback* = proc(view: EmbedView, tab: TabID, fd: int32)
  ResizeCallback* = proc(view: EmbedView, size: vmath.IVec2)
  ProcessFaultCallback* = proc(view: EmbedView, process: Process)
  PageTitleCallback* = proc(view: EmbedView, tab: TabID, title: string)
  CursorShapeCallback* = proc(view: EmbedView, predef: CursorPredefined)

  EmbedViewCallbacks* = object
    onFrameDrawn*: FrameDrawnCallback
    onResize*: ResizeCallback
    onProcessFault*: ProcessFaultCallback
    onPageTitleChange*: PageTitleCallback
    onSetCursorShape*: CursorShapeCallback

  EmbedViewObj = object
    master*: Master
    callbacks*: EmbedViewCallbacks

    frameAcked*: bool

    bufferFd*: int32
    bufferStride*: uint32

    pollingFd*: int32

  EmbedView* = ref EmbedViewObj

{.push inline, raises: [].}
func `onFrameDrawn=`*(view: EmbedView, cb: FrameDrawnCallback) =
  view.callbacks.onFrameDrawn = cb

func `onResize=`*(view: EmbedView, cb: ResizeCallback) =
  view.callbacks.onResize = cb

func `onProcessFault=`*(view: EmbedView, cb: ProcessFaultCallback) =
  view.callbacks.onProcessFault = cb

func `onPageTitleChange=`*(view: EmbedView, cb: PageTitleCallback) =
  view.callbacks.onPageTitleChange = cb

func `onSetCursorShape=`*(view: EmbedView, cb: CursorShapeCallback) =
  view.callbacks.onSetCursorShape = cb

{.pop.}

converter u32*(id: TabID): uint32 =
  cast[uint32](id)
