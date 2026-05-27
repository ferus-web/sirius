## Core routines for graphics
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import pkg/[nanovg, vmath], pkg/surfer/backend/wayland/bindings/[gles2]
import components/gfx/[painter, types]

proc drawFrame*(ctx: RenderingContext) =
  glViewport(0, 0, ctx.renderSize.x.GLsizei, ctx.renderSize.y.GLsizei)
  glClearColor(1.0, 1.0, 1.0, 1.0)
  glClear(GL_COLOR_BUFFER_BIT or GL_STENCIL_BUFFER_BIT)

  ctx.vg.beginFrame(ctx.renderSize.x, ctx.renderSize.y, 1.0'f32)
    # TODO: Use the fractional scale ratio that surfer gives us!!!

  drawTree(ctx)

  ctx.vg.endFrame()

proc resize*(ctx: RenderingContext, size: vmath.Vec2) =
  ctx.renderSize = size
