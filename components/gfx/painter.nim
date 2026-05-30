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
  draw(ctx, ctx.tree)
