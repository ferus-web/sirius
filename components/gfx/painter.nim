## Painter implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[monotimes, tables, times, options]
import pkg/[nanovg, shakar, vmath], pkg/nanovg/wrapper
import
  components/css/types,
  components/gfx/types,
  components/layout/[output_manager, types],
  components/os/fonts

proc drawNodeTextUnderline(ctx: RenderingContext, node: LayoutNode) =
  var yLevel: float32

  case node.textDecoration.line
  of TextDecorationLine.None:
    return
  of TextDecorationLine.Underline:
    yLevel = node.absolutePos.y + node.dimensions.y
  of TextDecorationLine.Overline:
    yLevel = node.absolutePos.y
  of TextDecorationLine.LineThrough:
    yLevel = node.absolutePos.y + (node.dimensions.y * 0.5'f32)
  of TextDecorationLine.Blink:
    discard "Deprecated"

  ctx.vg.beginPath()
  ctx.vg.moveTo(node.absolutePos.x, yLevel)
  ctx.vg.lineTo(node.absolutePos.x + node.dimensions.x, yLevel)
  ctx.vg.strokeColor(rgba(node.color.r, node.color.g, node.color.b, node.color.a))
    # TODO: Support for `text-decoration-color` in the CSS subsystem
  ctx.vg.strokeWidth(2'f32) # TODO: Support for `text-decoration-thickness`
  ctx.vg.stroke()

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
    if ctx.paintDebugBounds:
      ctx.vg.beginPath()
      ctx.vg.rect(
        node.absolutePos.x + ctx.viewerPosition.x,
        node.absolutePos.y + ctx.viewerPosition.y,
        node.dimensions.x,
        node.dimensions.y,
      )
      ctx.vg.strokeColor(rgb(255, 0, 0))
      ctx.vg.stroke()

    if node.imageContent != nil:
      let
        dx = node.absolutePos.x + ctx.viewerPosition.x
        dy = node.absolutePos.y + ctx.viewerPosition.y
        dw = node.dimensions.x
        dh = node.dimensions.y

      if not ctx.imageTextures.contains(cast[pointer](node.imageContent)):
        ctx.imageTextures[cast[pointer](node.imageContent)] = ctx.vg.createImageRGBA(
          w = node.imageContent.width.int32,
          h = node.imageContent.height.int32,
          imageFlags = {ifPremultiplied},
          data = cast[ptr byte](node.imageContent.data[0].addr),
        )

      ctx.vg.beginPath()
      ctx.vg.rect(dx, dy, dw, dh)
      ctx.vg.fillPaint(
        ctx.vg.imagePattern(
          dx,
          dy,
          dw,
          dh,
          0'f32,
          ctx.imageTextures[cast[pointer](node.imageContent)],
          1'f32,
        )
      )
      ctx.vg.fill()
  of DisplayMode.Anonymous:
    ctx.vg.beginPath()

    ctx.vg.fontSize(ctx.outputManager.computePixels(&node.fontSize))
    ctx.vg.fontFace(cast[nanovg.Font](node.fontFamily.impl))
    ctx.vg.fillColor(rgba(node.color.r, node.color.g, node.color.b, node.color.a))
    ctx.vg.textAlign(haLeft, vaTop)
    discard ctx.vg.text(
      node.absolutePos.x + ctx.viewerPosition.x,
      node.absolutePos.y + ctx.viewerPosition.y,
      node.content,
    )
    drawNodeTextUnderline(ctx, node)

  for child in node.children:
    draw(ctx, child)

proc drawTree*(ctx: RenderingContext) =
  let currTime = getMonoTime()

  let delta = float32(inMilliseconds(currTime - ctx.lastRender)) / 100'f32
  if ctx.scrollVelocity > 0'f32:
    ctx.scrollVelocity = max(0'f32, ctx.scrollVelocity - delta)
  elif ctx.scrollVelocity < 0'f32:
    ctx.scrollVelocity = min(0'f32, ctx.scrollVelocity + delta)

  ctx.viewerPosition.y += -ctx.scrollVelocity

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

  ctx.lastRender = currTime
