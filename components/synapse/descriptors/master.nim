## IPC descriptors and operations for the Master process that can be invoked by various different processes
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

type MasterOp* {.pure, size: sizeof(uint16).} = enum
  FrameDrawn
    ## Sent by the Renderer in response to the master sending a `DrawFrame`. The master will not send any further frame-drawing requests until it receives this.
  UseGraphicsFD
    ## Sent by the Renderer when it wants the master to present a particular DMA-BUF file descriptor via the browser's surface.
