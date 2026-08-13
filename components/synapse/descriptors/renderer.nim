## IPC descriptors and operations for the Renderer process that can be invoked by the master
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

type RenderOp* {.pure, size: sizeof(uint16).} = enum
  GotoURL
  DrawFrame
  ResizeRenderTarget
  Close
