## IPC descriptors and operations for the Renderer process that can be invoked by the master
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

type RenderOp* {.pure, size: sizeof(uint16).} = enum
  GotoURL
  DrawFrame
  ResizeRenderTarget
  Close
  ViewportScroll
  CursorMotion
  CursorClick
  KeyPressed
  SendGraphicsFD
    # HACK: This is a bad way to do things. It means that we rely solely on clients behaving well. Maybe we can guard the response UseGraphicsFD, but eh.
