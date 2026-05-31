## Painter implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/tables, options
import pkg/[nanovg, shakar, vmath]
import
  components/gfx/types, components/layout/[output_manager, types], components/os/fonts

proc draw(ctx: RenderingContext, node: LayoutNode) =
  if node == nil:
    return

  ctx.vg.beginPath()
  ctx.vg.rect(
    node.absolutePos.x + ctx.viewerPosition.x,
    node.absolutePos.y + ctx.viewerPosition.y,
    node.dimensions.x,
    node.dimensions.y,
  )
  ctx.vg.fillColor(
    rgba(
      node.backgroundColor.r, node.backgroundColor.g, node.backgroundColor.b,
      node.backgroundColor.a,
    )
  )
  ctx.vg.fill()

  case node.display
  of DisplayMode.Block, DisplayMode.Inline:
    when defined(gfxPaintBounds):
      ctx.vg.beginPath()
      ctx.vg.rect(
        node.absolutePos.x + ctx.viewerPosition.x,
        node.absolutePos.y + ctx.viewerPosition.y,
        node.dimensions.x,
        node.dimensions.y,
      )
      ctx.vg.strokeColor(rgb(255, 0, 0))
      ctx.vg.stroke()
    else:
      discard
  of DisplayMode.Anonymous:
    ctx.vg.beginPath()

    ctx.vg.fontSize(ctx.outputManager.computePixels(&node.fontSize))
    ctx.vg.fontFace(cast[nanovg.Font](node.fontFamily.impl))
    ctx.vg.fillColor(rgba(node.color.r, node.color.g, node.color.b, node.color.a))
    ctx.vg.textAlign(haLeft, vaTop)
    # echo $node.absolutePos & " @ " & $fontsize & "px"
    discard ctx.vg.text(
      node.absolutePos.x + ctx.viewerPosition.x,
      node.absolutePos.y + ctx.viewerPosition.y,
      node.content,
    )

  for child in node.children:
    draw(ctx, child)

proc drawTree*(ctx: RenderingContext) =
  # HACK: We don't have something like the Initial Containing Block right now,
  # so we can just paint the initial background as whatever <html> has. That
  # element should inherit <body>'s color if not specified for itself.
  ctx.vg.beginPath()
  ctx.vg.rect(0, 0, ctx.renderSize.x, ctx.renderSize.y)
  ctx.vg.fillColor(
    rgba(
      ctx.tree.backgroundColor.r, ctx.tree.backgroundColor.g,
      ctx.tree.backgroundColor.b, ctx.tree.backgroundColor.a,
    )
  )
  ctx.vg.fill()

  draw(ctx, ctx.tree)
