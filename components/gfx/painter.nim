## Painter implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[monotimes, tables, times, options]
import
  pkg/[shakar, vmath],
  pkg/figdraw/[commons, fignodes, figrender],
  pkg/figdraw/common/fonttypes,
  pkg/figdraw/vulkan/vulkan_context,
  pkg/figdraw/windowing/surfershim
import
  components/css/types,
  components/gfx/types,
  components/layout/[output_manager, types],
  components/os/fonts

#[ proc drawNodeTextUnderline(ctx: RenderingContext, node: LayoutNode) =
  let posX = node.absolutePos.x + ctx.viewerPosition.x
  var yLevel = node.absolutePos.y + ctx.viewerPosition.y

  case node.textDecoration.line
  of TextDecorationLine.None:
    return
  of TextDecorationLine.Underline:
    yLevel += node.dimensions.y
  of TextDecorationLine.Overline:
    discard
  # We're already at the correct position.
  of TextDecorationLine.LineThrough:
    yLevel += node.dimensions.y * 0.5'f32
  of TextDecorationLine.Blink:
    discard "Deprecated"

  ctx.vg.beginPath()
  ctx.vg.moveTo(posX, yLevel)
  ctx.vg.lineTo(posX + node.dimensions.x, yLevel)
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

  if *node.border.style:
    case &node.border.style
    of BorderStyle.None:
      discard
    # No border rendering.
    of BorderStyle.Dotted, BorderStyle.Dashed, BorderStyle.Double, BorderStyle.Groove,
        BorderStyle.Ridge, BorderStyle.Inset, BorderStyle.Outset:
      discard
    # TODO: Implement more of these.
    of BorderStyle.Solid:
      ctx.vg.beginPath()
      ctx.vg.rect(
        node.absolutePos.x + ctx.viewerPosition.x,
        node.absolutePos.y + ctx.viewerPosition.y,
        node.dimensions.x,
        node.dimensions.y,
      )

      if *node.border.color:
        let borderColor = &node.border.color
        ctx.vg.strokeColor(
          rgba(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
        )
      else:
        ctx.vg.strokeColor(rgba(node.color.r, node.color.g, node.color.b, node.color.a))

      if *node.border.width:
        ctx.vg.strokeWidth(ctx.outputManager.computePixels(&node.border.width))
      ctx.vg.stroke()

  for child in node.children:
    draw(ctx, child) ]#

proc invalidate*(ctx: RenderingContext) =
  ## Force the display list to be rebuilt.
  ctx.displayList = nil

proc presentDisplayList(ctx: RenderingContext) =
  ctx.fig.renderFrame(
    nodes = ctx.displayList, frameSize = vec2(ctx.renderSize), clearMain = true
  )

proc buildDisplayList(ctx: RenderingContext) =
  ctx.displayList = Renders()
  if ctx.tree == nil:
    # HACK: If the tree isn't present yet, just draw a white background.
    discard ctx.displayList.addRoot(
      0.ZLevel,
      Fig(
        kind: nkRectangle,
        zlevel: 0.ZLevel,
        screenBox: rect(0, 0, ctx.renderSize.x, ctx.renderSize.y),
        fill: fill(rgba(255, 255, 255, 255)),
      ),
    )
    return

  # HACK: We don't have something like the Initial Containing Block right now,
  # so we can just paint the initial background as whatever <html> has. That
  # element should inherit <body>'s color if not specified for itself.
  let root = ctx.displayList.addRoot(
    0.ZLevel,
    Fig(
      kind: nkRectangle,
      zlevel: 0.ZLevel,
      screenBox: rect(0, 0, ctx.renderSize.x, ctx.renderSize.y),
      fill: fill(ctx.tree.backgroundColor),
    ),
  )

  # draw(ctx, ctx.tree)

proc drawTree*(ctx: RenderingContext) =
  let currTime = getMonoTime()

  let delta = float32(inMilliseconds(currTime - ctx.lastRender)) / 100'f32
  if ctx.scrollVelocity > 0'f32:
    ctx.scrollVelocity = max(0'f32, ctx.scrollVelocity - delta)
  elif ctx.scrollVelocity < 0'f32:
    ctx.scrollVelocity = min(0'f32, ctx.scrollVelocity + delta)

  ctx.viewerPosition.y += -ctx.scrollVelocity

  if ctx.displayList == nil:
    buildDisplayList(ctx)

  echo ctx.renderSize
  ctx.fig.beginFrame()
  presentDisplayList(ctx)
  ctx.fig.endFrame()

  ctx.lastRender = currTime
