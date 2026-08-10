## Zygote IPC descriptors
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

type ZygoteOp* {.pure, size: sizeof(uint16).} = enum
  Spawn
