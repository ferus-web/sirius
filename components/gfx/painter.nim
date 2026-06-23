## Painter implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[hashes, monotimes, tables, times, options]
import
  pkg/[pixie, shakar, vmath],
  pkg/figdraw/[commons, fignodes, figrender],
  pkg/figdraw/common/[typefaces, fonttypes],
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

proc textLayout(
    box: Rect,
    spans: openArray[(FontStyle, string)],
    hAlign = Left,
    vAlign = Top,
    wrap = true,
): GlyphArrangement =
  typeset(
    rect(0, 0, box.w, box.h),
    spans,
    hAlign = hAlign,
    vAlign = vAlign,
    minContent = false,
    wrap = wrap,
  )

proc buildFigNodes*(ctx: RenderingContext, node: LayoutNode, parentIdx: FigIdx) =
  if node == nil:
    return

  let
    posX = node.absolutePos.x + ctx.viewerPosition.x
    posY = node.absolutePos.y + ctx.viewerPosition.y
    width = node.dimensions.x
    height = node.dimensions.y
    nodeScreenBox = rect(posX, posY, width, height)

  var containerFig = Fig(
    kind: nkRectangle, parent: parentIdx, zlevel: 0.ZLevel, screenBox: nodeScreenBox
  )

  if node.backgroundColor.a > 0:
    containerFig.fill = fill(node.backgroundColor)

  if *node.border.style and &node.border.style == BorderStyle.Solid:
    let bColor =
      if *node.border.color:
        &node.border.color
      else:
        node.color
    let bWidth =
      if *node.border.width:
        ctx.outputManager.computePixels(&node.border.width)
      else:
        1.0'f32
    containerFig.stroke = RenderStroke(weight: bWidth, fill: fill(bColor))

  # Push the layout node container to the flat display list and grab its new Handle ID
  let currentIdx = ctx.displayList.addChild(ZLevel(0), parentIdx, containerFig)

  case node.display
  of DisplayMode.Block, DisplayMode.Inline:
    if ctx.paintDebugBounds:
      discard ctx.displayList.addChild(
        ZLevel(0),
        currentIdx,
        Fig(
          kind: nkRectangle,
          parent: currentIdx,
          zlevel: 0.ZLevel,
          screenBox: nodeScreenBox,
          stroke: RenderStroke(weight: 1'f32, fill: fill(rgba(255, 0, 0, 255))),
        ),
      )

    if node.imageContent != Hash(0) and node.imageBuffer != nil:
      discard ctx.displayList.addChild(
        ZLevel(0),
        currentIdx,
        Fig(
          kind: nkImage,
          parent: currentIdx,
          zlevel: 0.ZLevel,
          screenBox: nodeScreenBox,
          image: ImageStyle(
            id: cast[ImageId](node.imageContent), fill: fill(rgba(255, 255, 255, 255))
          ),
        ),
      )
  of DisplayMode.Anonymous:
    let fSize = ctx.outputManager.computePixels(&node.fontSize)
    let fStyle = FontStyle(
      font: FigFont(typefaceId: cast[TypefaceId](node.fontFamily.impl), size: fSize),
      color: fill(node.color),
    )

    discard ctx.displayList.addChild(
      ZLevel(0),
      currentIdx,
      Fig(
        kind: nkText,
        parent: currentIdx,
        zlevel: 0.ZLevel,
        screenBox: nodeScreenBox,
        textLayout: textLayout(
          box = rect(0, 0, width, height),
          spans = [(fStyle, node.content)],
          hAlign = Left,
          vAlign = Top,
          wrap = true,
        ),
      ),
    )

    if node.textDecoration.line notin {
      TextDecorationLine.None, TextDecorationLine.Blink
    }:
      var yLevel = posY

      case node.textDecoration.line
      of TextDecorationLine.Underline:
        yLevel += height
      of TextDecorationLine.Overline:
        discard
      of TextDecorationLine.LineThrough:
        yLevel += height * 0.5'f32
      of TextDecorationLine.Blink, TextDecorationLine.None:
        unreachable

      discard ctx.displayList.addChild(
        ZLevel(0),
        currentIdx,
        Fig(
          kind: nkRectangle,
          parent: currentIdx,
          zlevel: 0.ZLevel,
          screenBox: rect(posX, yLevel, width, 2'f32),
          fill: fill(node.color),
        ),
      )

  for childNode in node.children:
    buildFigNodes(ctx, childNode, currentIdx)

proc invalidate*(ctx: RenderingContext) =
  ## Force the display list to be rebuilt.
  ctx.displayList = nil
  ctx.rootNode.reset()
  ctx.transformNode.reset()

  for name, img in ctx.imageCache:
    loadImage(imgId(name), img)

proc presentDisplayList(ctx: RenderingContext) =
  ctx.fig.renderFrame(
    nodes = ctx.displayList, frameSize = vec2(ctx.renderSize), clearMain = true
  )

proc buildDisplayList(ctx: RenderingContext) =
  ctx.displayList = Renders()
  if ctx.tree == nil:
    # HACK: If the tree isn't present yet, just draw a white background.
    ctx.rootNode = ctx.displayList.addRoot(
      0.ZLevel,
      Fig(
        kind: nkRectangle,
        zlevel: 0.ZLevel,
        screenBox: rect(0, 0, ctx.renderSize.x, ctx.renderSize.y),
        fill: fill(rgba(255, 255, 255, 255)),
      ),
    )

    ctx.transformNode = ctx.displayList.addChild(
      0.ZLevel,
      ctx.rootNode,
      Fig(kind: nkTransform, transform: TransformStyle(translation: vec2(0, 0))),
    )
    return

  # HACK: We don't have something like the Initial Containing Block right now,
  # so we can just paint the initial background as whatever <html> has. That
  # element should inherit <body>'s color if not specified for itself.
  ctx.rootNode = ctx.displayList.addRoot(
    0.ZLevel,
    Fig(
      kind: nkRectangle,
      zlevel: 0.ZLevel,
      screenBox: rect(0, 0, ctx.renderSize.x, ctx.renderSize.y),
      fill: fill(ctx.tree.backgroundColor),
    ),
  )

  ctx.transformNode = ctx.displayList.addChild(
    0.ZLevel,
    ctx.rootNode,
    Fig(kind: nkTransform, transform: TransformStyle(translation: vec2(0, 0))),
  )

  buildFigNodes(ctx, ctx.tree, ctx.transformNode)
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

  ctx.fig.beginFrame()
  presentDisplayList(ctx)
  ctx.fig.endFrame()

  ctx.displayList.layers[ZLevel(0)].nodes[cast[int16](ctx.transformNode)].transform.translation =
    ctx.viewerPosition # HACK: This works, but is it sane? I don't think so.

  ctx.lastRender = currTime
