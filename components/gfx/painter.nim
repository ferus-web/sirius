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
  components/dom/[dom, tags],
  components/os/fonts

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
    posX = node.absolutePos.x
    posY = node.absolutePos.y
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

    if node.domNode != nil and node.domNode of tags.HTMLInputElement:
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
            spans = [(fStyle, HTMLInputElement(node.domNode).inputBuffer)],
              # TODO: Placeholders
            hAlign = Left,
            vAlign = Top,
            wrap = true,
          ),
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
    var arrangement = node.arrangement
    for i, _ in arrangement.spanColors:
      arrangement.spanColors[i] = fill(node.color)

    discard ctx.displayList.addChild(
      ZLevel(0),
      currentIdx,
      Fig(
        kind: nkText,
        parent: currentIdx,
        zlevel: ZLevel(0),
        screenBox: nodeScreenBox,
        textLayout: ensureMove(arrangement),
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
      ZLevel(0),
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

  ctx.displayList.layers[ZLevel(0)].nodes[cast[int16](ctx.transformNode)].transform.translation =
    ctx.viewerPosition

  ctx.fig.beginFrame()
  presentDisplayList(ctx)
  ctx.fig.endFrame()

  ctx.lastRender = currTime
