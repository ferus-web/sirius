## IPC descriptors and operations for the Master process that can be invoked by various different processes.
##
## For the documentation on these operations, check `docs/sandbox/MASTER.md`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

type MasterOp* {.pure, size: sizeof(uint16).} = enum
  FrameDrawn
  UseGraphicsFD
  TargetResized
  SetPageTitle
  SetPCursorShape
  AlertMessage
  UpdateNavigation
