## Painter implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[hashes, deques, importutils, monotimes, tables, times, options]
import
  pkg/[pixie, shakar, vmath],
  pkg/figdraw/[commons, fignodes, figrender],
  pkg/figdraw/common/[typefaces, fonttypes],
  pkg/figdraw/utils/drawutils,
  pkg/figdraw/vulkan/vulkan_context
import
  components/css/types,
  components/gfx/types,
  components/layout/[output_manager, types],
  components/dom/[dom, tags],
  components/os/fonts,
  components/html/form/types

privateAccess(VulkanContext)

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

proc drawNodeBorder(
    ctx: RenderingContext, node: LayoutNode, parentIdx: FigIdx, nodeScreenBox: Rect
): Option[Fig] =
  let
    borderColor =
      if *node.border.color:
        &node.border.color
      else:
        node.color
    borderWidth =
      if *node.border.width:
        ctx.outputManager.computePixels(&node.border.width)
      else:
        1.0'f32

  case &node.border.style
  of BorderStyle.Solid:
    var containerFig = Fig(
      kind: nkRectangle, parent: parentIdx, zlevel: 0.ZLevel, screenBox: nodeScreenBox
    )

    containerFig.stroke = RenderStroke(weight: borderWidth, fill: fill(borderColor))
    return some(containerFig)
  of BorderStyle.Dashed:
    var containerFig = figDashedRoundedRectBorder(
      nodeScreenBox,
      default(array[DirectionCorners, uint16]),
      borderColor,
      weight = borderWidth,
      dashLength = 3 * borderWidth,
        # these are kind of arbitrary, but they seem to look the closest to chromium and epiphany
      gapLength = 2 * borderWidth,
      offset = 16.0'f32,
      cap = scSquare,
    )

    return some(containerFig)
  of BorderStyle.Dotted:
    var containerFig = figDottedRoundedRectBorder(
      nodeScreenBox,
      default(CornerRadii),
      borderColor,
      weight = borderWidth,
      gapLength = 2 * borderWidth,
      offset = 16.0'f32,
    ) # TODO: This creates arcs. we need a path that doesn't.

    return some(containerFig)
  else:
    discard # warn "Unhandled border style", style = &node.border.style

proc drawInputElement(
    ctx: RenderingContext,
    node: LayoutNode,
    currentIdx: FigIdx,
    nodeScreenBox: Rect,
    width, height: float32,
) =
  let fSize = ctx.outputManager.computePixels(&node.fontSize)
  let fStyle = FontStyle(
    font: FigFont(typefaceId: cast[TypefaceId](node.fontFamily.impl), size: fSize),
    color: fill(node.color),
  )
  let input = HTMLInputElement(node.domNode)
  let inputKind =
    if !input.kind:
      InputKind.Text
    else:
      &input.kind

  case inputKind
  of InputKind.Text, InputKind.Search:
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
  of InputKind.Submit:
    let text =
      if *input.value:
        &input.value
      else:
        "Submit Query"

    let buttonBox = ctx.displayList.addChild(
      ZLevel(0),
      currentIdx,
      Fig(
        kind: nkRectangle,
        parent: currentIdx,
        zlevel: 0.ZLevel,
        screenBox: nodeScreenBox,
        fill: fill(node.backgroundColor),
      ),
    )

    discard ctx.displayList.addChild(
      ZLevel(0),
      currentIdx,
      Fig(
        kind: nkText,
        parent: buttonBox,
        zlevel: 0.ZLevel,
        screenBox: nodeScreenBox,
        textLayout: textLayout(
          box = rect(0, 0, width, height),
          spans = [(fStyle, text)],
          hAlign = Left,
          vAlign = Top,
          wrap = true,
        ),
      ),
    )
  else:
    discard

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

  var borderFig: Option[Fig]

  if *node.border.style:
    borderFig = ctx.drawNodeBorder(node, parentIdx, nodeScreenBox)

  let currentIdx = ctx.displayList.addChild(ZLevel(0), parentIdx, containerFig)

  if *borderFig:
    discard ctx.displayList.addChild(ZLevel(0), parentIdx, &borderFig)

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
      drawInputElement(ctx, node, currentIdx, nodeScreenBox, width, height)

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
    for run in node.textRuns:
      var arrangement = run.arrangement
      for i, _ in arrangement.spanColors:
        arrangement.spanColors[i] = fill(node.color)

      let
        runPosX = posX + run.pos.x
        runPosY = posY + run.pos.y
        runWidth = arrangement.bounding.w
        runHeight = arrangement.bounding.h
        runScreenBox = rect(runPosX, runPosY, runWidth, runHeight)

      discard ctx.displayList.addChild(
        ZLevel(0),
        currentIdx,
        Fig(
          kind: nkText,
          parent: currentIdx,
          zlevel: ZLevel(0),
          screenBox: runScreenBox,
          textLayout: ensureMove(arrangement),
        ),
      )

      if node.textDecoration.line notin
          {TextDecorationLine.None, TextDecorationLine.Blink}:
        var i = 0
        while i < node.textRuns.len:
          let startRun = node.textRuns[i]
          var endRun = startRun
          let lineY = startRun.pos.y
          var maxLineHeight = startRun.arrangement.bounding.h

          # Find all subsequent runs that are on the exact Y val
          var j = i + 1
          while j < node.textRuns.len and abs(node.textRuns[j].pos.y - lineY) < 0.5'f32:
            endRun = node.textRuns[j]
            maxLineHeight = max(maxLineHeight, endRun.arrangement.bounding.h)
            inc j

          let
            # then we basically just calculate the contiguous chunk across the Y level
            lineStartX = posX + startRun.pos.x
            lineEndX = posX + endRun.pos.x + endRun.arrangement.bounding.w
            lineWidth = lineEndX - lineStartX
            linePosY = posY + lineY

          var yLevel = linePosY

          case node.textDecoration.line
          of TextDecorationLine.Underline:
            yLevel += maxLineHeight
          of TextDecorationLine.Overline:
            discard
          of TextDecorationLine.LineThrough:
            yLevel += maxLineHeight * 0.5'f32
          of TextDecorationLine.Blink, TextDecorationLine.None:
            unreachable

          discard ctx.displayList.addChild(
            ZLevel(0),
            currentIdx,
            Fig(
              kind: nkRectangle,
              parent: currentIdx,
              zlevel: 0.ZLevel,
              screenBox: rect(lineStartX, yLevel, lineWidth, 2'f32),
              fill: fill(node.color),
            ),
          )

          i = j
  for childNode in node.children:
    buildFigNodes(ctx, childNode, currentIdx)

proc invalidate*(ctx: RenderingContext) =
  ## Force the display list to be rebuilt.
  ctx.displayList = nil
  ctx.rootNode.reset()
  ctx.transformNode.reset()

  while ctx.imageReuploadQueue.len > 0:
    let name = ctx.imageReuploadQueue.popFirst()
    loadImage(imgId(name), ctx.imageCache[name])

func reuploadImage*(ctx: RenderingContext, name: string) =
  ctx.imageReuploadQueue.addLast(name)

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
  let lastAtlasSize = VulkanContext(ctx.fig.ctx).atlasSize
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

  let vk = VulkanContext(ctx.fig.ctx)
  vk.beginFrame(frameSize = ctx.renderSize)
  presentDisplayList(ctx)
  vk.endFrame()

  if lastAtlasSize != vk.atlasSize:
    for name, _ in ctx.imageCache:
      ctx.reuploadImage(name)

  ctx.lastRender = currTime
