## Core routines for graphics
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import pkg/[vmath]
import components/gfx/[painter, types]

proc resize*(ctx: RenderingContext, size: vmath.Vec2) =
  ctx.renderSize = size
  ctx.invalidate()
