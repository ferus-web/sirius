## Flow layout implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[hashes, options, tables]
import std/strutils except Whitespace
import
  components/style/types,
  components/css/types,
  components/dom/[dom, tags],
  components/layout/[output_manager, types],
  components/os/fonts
import pkg/[bumpy, chronicles, shakar, vmath]

logScope:
  topics = "layout/flow"

type
  BlockFloatingContext* = ref object
    leftFloats*: seq[Rect]
    rightFloats*: seq[Rect]

  FlowContext* = object
    document*: dom.Document

    availableWidth*: float32
    outputManager*: OutputManager
    fontProvider*: FontProvider
    parentExplicitHeight*: Option[float32] = none(float32)

    bfc*: BlockFloatingContext

proc resolveMargin*(
    value: Option[CSSValue],
    availableWidth: float32,
    outputManager: OutputManager,
    fontSize: float32 = 0'f32,
): float32 =
  if !value:
    return 0.0'f32

  let value = &value
  case value.kind
  of CSSValueKind.Dimension:
    return outputManager.computePixels(
      value, relativeBase = availableWidth, fontSize = fontSize
    )
  of CSSValueKind.Integer:
    return float32(value.num)
  else:
    # warn "Unhandled type for margin property", got = value.kind
    return 0.0'f32

proc resolveLineHeight*(
    value: Option[CSSValue], fontSize: float32, outputManager: OutputManager
): float32 =
  if !value:
    return fontSize * 1.2'f32

  let value = &value
  case value.kind
  of CSSValueKind.Dimension:
    return
      outputManager.computePixels(value, relativeBase = fontSize, fontSize = fontSize)
  of CSSValueKind.Float:
    return value.flt * fontSize
  of CSSValueKind.Integer:
    return float32(value.num) * fontSize
  else:
    return fontSize * 1.2'f32

func processTextContent(text: var string, whitespaceBehaviour: Whitespace) =
  # FIXME: This is probably a bad way to do it.
  case whitespaceBehaviour
  of Whitespace.Normal, Whitespace.NoWrap, Whitespace.PreLine:
    for i, c in text:
      if c in {'\n', '\r', '\t'}:
        text[i] = cast[char](0x20) # Replace the whitespace character with a space
  else:
    # TODO: Implement other behaviors in other components!
    discard

proc applyClearance(
    node: LayoutNode,
    absParentY: float32,
    currentY: var float32,
    bfc: BlockFloatingContext,
) =
  # TODO: Ideally this should be on the LayoutNode and computed in node_builder, but
  # I'm too lazy to do it properly for now. Gotta move it there eventually for consistency though
  if "clear" notin node.style:
    return

  let clearProp = node.style["clear"]
  if clearProp.kind != CSSValueKind.String:
    return

  let clearVal = toLowerAscii(clearProp.str)
  var maxBottom = absParentY + currentY

  if clearVal in ["left", "both"]:
    for f in bfc.leftFloats:
      maxBottom = max(maxBottom, f.y + f.h)

  if clearVal in ["right", "both"]:
    for f in bfc.rightFloats:
      maxBottom = max(maxBottom, f.y + f.h)

  currentY = max(currentY, maxBottom - absParentY)

proc computeLayout*(ctx: FlowContext, node: LayoutNode, parent: vmath.Vec2) =
  node.absolutePos = parent

  let isImage =
    node.domNode != nil and node.domNode of tags.HTMLImageElement and
    Element(node.domNode).tagType() == TAG_IMG

  let isInput =
    node.domNode != nil and node.domNode of tags.HTMLInputElement and
    Element(node.domNode).tagType() == TAG_INPUT

  if isImage:
    let element = HTMLImageElement(node.domNode)
    if node.imageContent != Hash(0) and node.imageBuffer != nil:
      let img = node.imageBuffer
      var
        intrinsicWidth = float32(img.width)
        intrinsicHeight = float32(img.height)

      let aspect =
        if intrinsicHeight > 0'f32:
          intrinsicWidth / intrinsicHeight
        else:
          1'f32

      if *element.width:
        intrinsicWidth = float32(&element.width)
      if *element.height:
        intrinsicHeight = float32(&element.height)

      if node.dimensions.x == 0'f32 and node.dimensions.y == 0'f32:
        node.dimensions.x = intrinsicWidth
        node.dimensions.y = intrinsicHeight
      elif node.dimensions.x > 0'f32 and node.dimensions.y == 0'f32:
        node.dimensions.y = node.dimensions.x / aspect
      elif node.dimensions.y > 0'f32 and node.dimensions.x == 0'f32:
        node.dimensions.x = node.dimensions.y * aspect

    if node.display == DisplayMode.Block and node.dimensions.x > ctx.availableWidth:
      let ratio = ctx.availableWidth / node.dimensions.x
      node.dimensions = vec2(ctx.availableWidth, node.dimensions.y * ratio)
    return

  if isInput:
    let fSize =
      if *node.fontSize:
        computePixels(ctx.outputManager, &node.fontSize, fontSize = 16'f32)
      else:
        16'f32

    let
      intrinsicWidth =
        if !node.width:
          fSize # Compact default width for radio/checkbox inputs
        else:
          ctx.outputManager.computePixels(
            &node.width, relativeBase = ctx.availableWidth, fontSize = fSize
          )
      intrinsicHeight =
        if !node.height:
          fSize
        else:
          ctx.outputManager.computePixels(
            &node.height,
            relativeBase =
              (if *ctx.parentExplicitHeight: &ctx.parentExplicitHeight
              else: 0'f32),
            fontSize = fSize,
          )

    if node.dimensions.x == 0'f32:
      node.dimensions.x = intrinsicWidth
    if node.dimensions.y == 0'f32:
      node.dimensions.y = intrinsicHeight

    if node.display == DisplayMode.Block and node.dimensions.x > ctx.availableWidth:
      node.dimensions.x = ctx.availableWidth

    return

  let
    fontSize =
      if *node.fontSize:
        computePixels(ctx.outputManager, &node.fontSize, fontSize = 16'f32)
      else:
        16'f32

    borderWidth =
      if *node.border.width and *node.border.style and
          (&node.border.style) != BorderStyle.None:
        computePixels(ctx.outputManager, &node.border.width, fontSize = fontSize)
      else:
        0.0'f32

    padTop =
      resolveMargin(node.padding.top, ctx.availableWidth, ctx.outputManager, fontSize)
    padBottom = resolveMargin(
      node.padding.bottom, ctx.availableWidth, ctx.outputManager, fontSize
    )
    padLeft =
      resolveMargin(node.padding.left, ctx.availableWidth, ctx.outputManager, fontSize)
    padRight =
      resolveMargin(node.padding.right, ctx.availableWidth, ctx.outputManager, fontSize)

    explicitWidth =
      if *node.width:
        some(
          ctx.outputManager.computePixels(
            &node.width, relativeBase = ctx.availableWidth, fontSize = fontSize
          )
        )
      else:
        none(float32)

    explicitHeight =
      if *node.height:
        some(
          ctx.outputManager.computePixels(
            &node.height,
            relativeBase =
              (if *ctx.parentExplicitHeight: &ctx.parentExplicitHeight
              else: 0'f32),
            fontSize = fontSize,
          )
        )
      else:
        none(float32)

    layoutWidth =
      if *explicitWidth:
        &explicitWidth + padLeft + padRight + (borderWidth * 2.0'f32)
      else:
        ctx.availableWidth

    innerAvailableWidth =
      max(0.0'f32, layoutWidth - (borderWidth * 2.0'f32) - padLeft - padRight)

  proc getLineBounds(y: float32): tuple[left, right: float32] =
    var bounds =
      (left: borderWidth + padLeft, right: layoutWidth - borderWidth - padRight)
    let absY = node.absolutePos.y + y

    for f in ctx.bfc.leftFloats:
      if absY >= f.y and absY < (f.y + f.h):
        bounds.left = max(bounds.left, (f.x + f.w) - node.absolutePos.x)

    for f in ctx.bfc.rightFloats:
      if absY >= f.y and absY < (f.y + f.h):
        bounds.right = min(bounds.right, f.x - node.absolutePos.x)

    ensureMove(bounds)

  proc findFloatY(startY: float32, neededWidth: float32): float32 =
    var y = startY
    while true:
      let bounds = getLineBounds(y)
      if (bounds.right - bounds.left) >= neededWidth - 0.05'f32:
        return y

      let absY = node.absolutePos.y + y
      var nextAbsY = high(float32)
      for f in ctx.bfc.leftFloats:
        if absY >= f.y and absY < (f.y + f.h):
          nextAbsY = min(nextAbsY, f.y + f.h)
      for f in ctx.bfc.rightFloats:
        if absY >= f.y and absY < (f.y + f.h):
          nextAbsY = min(nextAbsY, f.y + f.h)

      if nextAbsY == high(float32) or (nextAbsY - node.absolutePos.y) <= y:
        return y
      y = nextAbsY - node.absolutePos.y

  var hasInline = false
  for child in node.children:
    if child.display in {DisplayMode.Anonymous, DisplayMode.Inline}:
      hasInline = true
      break

  if not hasInline:
    node.dimensions = vec2(layoutWidth, borderWidth + padTop)
    var currentY = borderWidth + padTop
    var lastFloatY = currentY

    for child in node.children:
      applyClearance(child, node.absolutePos.y, currentY, ctx.bfc)

      let
        childFontSize =
          if *child.fontSize:
            computePixels(ctx.outputManager, &child.fontSize, fontSize = fontSize)
          else:
            fontSize
        marginTop = resolveMargin(
          child.margins.top, innerAvailableWidth, ctx.outputManager, childFontSize
        )
        marginBottom = resolveMargin(
          child.margins.bottom, innerAvailableWidth, ctx.outputManager, childFontSize
        )
        marginLeft = resolveMargin(
          child.margins.left, innerAvailableWidth, ctx.outputManager, childFontSize
        )
        marginRight = resolveMargin(
          child.margins.right, innerAvailableWidth, ctx.outputManager, childFontSize
        )

      if child.floatMode in {FloatMode.Left, FloatMode.Right}:
        let tempPos = vec2(
          node.absolutePos.x + borderWidth + padLeft, node.absolutePos.y + currentY
        )
        computeLayout(
          FlowContext(
            document: ctx.document,
            availableWidth: innerAvailableWidth,
            outputManager: ctx.outputManager,
            fontProvider: ctx.fontProvider,
            parentExplicitHeight: explicitHeight,
            bfc: BlockFloatingContext(),
          ),
          node = child,
          parent = tempPos,
        )

        let outerW = child.dimensions.x + marginLeft + marginRight
        let outerH = child.dimensions.y + marginTop + marginBottom
        let floatY = findFloatY(max(currentY, lastFloatY), outerW)
        lastFloatY = floatY
        let bounds = getLineBounds(floatY)

        let finalX =
          if child.floatMode == FloatMode.Left:
            node.absolutePos.x + bounds.left + marginLeft
          else:
            node.absolutePos.x + (bounds.right - child.dimensions.x - marginRight)
        let finalY = node.absolutePos.y + floatY + marginTop

        computeLayout(
          FlowContext(
            document: ctx.document,
            availableWidth: innerAvailableWidth,
            outputManager: ctx.outputManager,
            fontProvider: ctx.fontProvider,
            parentExplicitHeight: explicitHeight,
            bfc: BlockFloatingContext(),
          ),
          node = child,
          parent = vec2(finalX, finalY),
        )

        let floatRect = rect(finalX - marginLeft, finalY - marginTop, outerW, outerH)
        if child.floatMode == FloatMode.Left:
          ctx.bfc.leftFloats.add(floatRect)
        else:
          ctx.bfc.rightFloats.add(floatRect)
        continue

      let childAvailableWidth =
        max(0.0'f32, innerAvailableWidth - marginLeft - marginRight)
      let cpos = vec2(
        node.absolutePos.x + borderWidth + padLeft + marginLeft,
        node.absolutePos.y + currentY + marginTop,
      )
      computeLayout(
        FlowContext(
          document: ctx.document,
          availableWidth: childAvailableWidth,
          outputManager: ctx.outputManager,
          fontProvider: ctx.fontProvider,
          parentExplicitHeight: explicitHeight,
          bfc: ctx.bfc,
        ),
        node = child,
        parent = cpos,
      )
      currentY += marginTop + child.dimensions.y + marginBottom

    node.dimensions.y = currentY + padBottom + borderWidth
  else:
    node.dimensions.x = 0'f32

    var cursor = vec2(borderWidth + padLeft, borderWidth + padTop)
    var currLineHeight: float32
    var maxLineWidth: float32
    var lastFloatY = cursor.y

    for child in node.children:
      applyClearance(child, node.absolutePos.y, cursor.y, ctx.bfc)

      let
        childFontSize =
          if *child.fontSize:
            computePixels(ctx.outputManager, &child.fontSize, fontSize = fontSize)
          else:
            fontSize
        marginTop = resolveMargin(
          child.margins.top, innerAvailableWidth, ctx.outputManager, childFontSize
        )
        marginBottom = resolveMargin(
          child.margins.bottom, innerAvailableWidth, ctx.outputManager, childFontSize
        )
        marginLeft = resolveMargin(
          child.margins.left, innerAvailableWidth, ctx.outputManager, childFontSize
        )
        marginRight = resolveMargin(
          child.margins.right, innerAvailableWidth, ctx.outputManager, childFontSize
        )

      if child.floatMode in {FloatMode.Left, FloatMode.Right}:
        let tempPos = vec2(node.absolutePos.x + cursor.x, node.absolutePos.y + cursor.y)
        computeLayout(
          FlowContext(
            document: ctx.document,
            outputManager: ctx.outputManager,
            fontProvider: ctx.fontProvider,
            availableWidth: innerAvailableWidth,
            parentExplicitHeight: explicitHeight,
            bfc: BlockFloatingContext(),
          ),
          node = child,
          parent = tempPos,
        )

        let outerW = child.dimensions.x + marginLeft + marginRight
        let outerH = child.dimensions.y + marginTop + marginBottom
        let floatY = findFloatY(max(cursor.y, lastFloatY), outerW)
        lastFloatY = floatY
        let bounds = getLineBounds(floatY)

        let finalX =
          if child.floatMode == FloatMode.Left:
            node.absolutePos.x + bounds.left + marginLeft
          else:
            node.absolutePos.x + (bounds.right - child.dimensions.x - marginRight)
        let finalY = node.absolutePos.y + floatY + marginTop

        computeLayout(
          FlowContext(
            document: ctx.document,
            outputManager: ctx.outputManager,
            fontProvider: ctx.fontProvider,
            availableWidth: innerAvailableWidth,
            parentExplicitHeight: explicitHeight,
            bfc: BlockFloatingContext(),
          ),
          node = child,
          parent = vec2(finalX, finalY),
        )

        let floatRect = rect(finalX - marginLeft, finalY - marginTop, outerW, outerH)
        if child.floatMode == FloatMode.Left:
          ctx.bfc.leftFloats.add(floatRect)
          if floatY == cursor.y:
            cursor.x = max(cursor.x, bounds.left + outerW)
        else:
          ctx.bfc.rightFloats.add(floatRect)
        continue

      if child.display == DisplayMode.Anonymous:
        child.textRuns.setLen(0)

        let lineHeight =
          resolveLineHeight(child.lineHeight, childFontSize, ctx.outputManager)

        let words = child.content.splitWhitespace()
        let spaceArrangement = ctx.fontProvider.loader.measureTextBounds(
          child.fontFamily,
          vec2(
            99999'f32, 999999'f32 #[ FIXME ]#
          ),
          childFontSize,
          TextAlignment.Left,
          none(string),
          " ",
        )
        let spaceWidth = spaceArrangement.bounding.w

        var bounds = getLineBounds(cursor.y)
        if cursor.x < bounds.left:
          cursor.x = bounds.left

        var lineStartIndex = 0'u
        proc alignCurrLine(
            child: LayoutNode, endIdx: uint, currentX: float32, rightBound: float32
        ) =
          if endIdx <= lineStartIndex:
            return

          # Subtract the trailing space of the last word to get the true visual width
          let actualContentEdge = currentX - spaceWidth
          let remainingSpace = rightBound - actualContentEdge

          if remainingSpace > 0'f32:
            let shift =
              case child.textAlignment
              of TextAlignment.Center:
                remainingSpace * 0.5'f32
              of TextAlignment.Right, TextAlignment.End:
                remainingSpace
              else:
                0.0'f32 # TODO: other alignment modes

            if shift > 0'f32:
              for i in lineStartIndex ..< endIdx:
                child.textRuns[i].pos.x += shift

        for word in words:
          let wordArr = ctx.fontProvider.loader.measureTextBounds(
            child.fontFamily,
            vec2(
              99999'f32, 999999'f32 #[ FIXME ]#
            ),
            childFontSize,
            TextAlignment.Left,
            none(string),
            word,
          )

          if cursor.x + wordArr.bounding.w > bounds.right and cursor.x > bounds.left:
            alignCurrLine(child, cast[uint](child.textRuns.len), cursor.x, bounds.right)
            lineStartIndex = cast[uint](child.textRuns.len)

            cursor.y += max(currLineHeight, lineHeight)
            currLineHeight = 0.0'f32

            bounds = getLineBounds(cursor.y)
            cursor.x = bounds.left

          let halfLeading = (lineHeight - childFontSize) * 0.5'f32
          let wordPos = vec2(cursor.x, cursor.y + halfLeading)

          child.textRuns &= TextRun(pos: wordPos, arrangement: wordArr)

          cursor.x += wordArr.bounding.w + spaceWidth
          currLineHeight = max(currLineHeight, max(lineHeight, wordArr.bounding.h))
          maxLineWidth = max(maxLineWidth, cursor.x + padRight + borderWidth)

        alignCurrLine(child, cast[uint](child.textRuns.len), cursor.x, bounds.right)

        child.dimensions = vec2(maxLineWidth, cursor.y + currLineHeight)
        child.absolutePos = node.absolutePos
      elif child.display == DisplayMode.Inline or (
        child.domNode of dom.Element and tagType(Element(child.domNode)) == TAG_INPUT
      ):
        var bounds = getLineBounds(cursor.y)
        if cursor.x < bounds.left:
          cursor.x = bounds.left

        var childHasBlockChildren: bool
        for grandchild in child.children:
          if grandchild.display == DisplayMode.Block and
              not (
                grandchild.domNode of dom.Element and
                Element(grandchild.domNode).tagType() == TAG_INPUT
              ):
            childHasBlockChildren = true
            break

        if childHasBlockChildren and (currLineHeight > 0'f32 or cursor.x > bounds.left):
          cursor.y += currLineHeight
          currLineHeight = 0'f32
          bounds = getLineBounds(cursor.y)
          cursor.x = bounds.left

        computeLayout(
          FlowContext(
            document: ctx.document,
            outputManager: ctx.outputManager,
            fontProvider: ctx.fontProvider,
            availableWidth: max(0.0'f32, bounds.right - cursor.x),
            parentExplicitHeight: explicitHeight,
            bfc:
              if child.floatMode != FloatMode.None:
                BlockFloatingContext()
              else:
                ctx.bfc,
          ),
          node = child,
          parent = vec2(node.absolutePos.x + cursor.x, node.absolutePos.y + cursor.y),
        )

        # If inline element overflowed the remaining line width, wrap it to the next line.
        if not childHasBlockChildren and cursor.x + child.dimensions.x > bounds.right and
            cursor.x > bounds.left:
          cursor.y +=
            max(
              currLineHeight,
              resolveLineHeight(child.lineHeight, childFontSize, ctx.outputManager),
            )
          currLineHeight = 0'f32
          bounds = getLineBounds(cursor.y)
          cursor.x = bounds.left

          computeLayout(
            FlowContext(
              document: ctx.document,
              outputManager: ctx.outputManager,
              fontProvider: ctx.fontProvider,
              availableWidth: max(0.0'f32, bounds.right - cursor.x),
              parentExplicitHeight: explicitHeight,
              bfc:
                if child.floatMode != FloatMode.None:
                  BlockFloatingContext()
                else:
                  ctx.bfc,
            ),
            node = child,
            parent = vec2(node.absolutePos.x + cursor.x, node.absolutePos.y + cursor.y),
          )

        if childHasBlockChildren:
          cursor.y += child.dimensions.y
          currLineHeight = 0'f32
          cursor.x = borderWidth + padLeft
          maxLineWidth = max(maxLineWidth, child.dimensions.x + padRight + borderWidth)
        else:
          let lineHeight =
            resolveLineHeight(child.lineHeight, childFontSize, ctx.outputManager)
          cursor.x += child.dimensions.x
          currLineHeight = max(currLineHeight, max(lineHeight, child.dimensions.y))
          maxLineWidth = max(maxLineWidth, cursor.x + padRight + borderWidth)
      elif child.display == DisplayMode.Block:
        if currLineHeight > 0'f32 or cursor.x > (borderWidth + padLeft):
          cursor.y += currLineHeight
          currLineHeight = 0'f32

        cursor.x = borderWidth + padLeft

        let blockPos = vec2(
          node.absolutePos.x + cursor.x + marginLeft,
          node.absolutePos.y + cursor.y + marginTop,
        )

        let childAvailableWidth =
          max(0.0'f32, innerAvailableWidth - marginLeft - marginRight)

        computeLayout(
          FlowContext(
            document: ctx.document,
            availableWidth: childAvailableWidth,
            outputManager: ctx.outputManager,
            fontProvider: ctx.fontProvider,
            parentExplicitHeight: explicitHeight,
            bfc: ctx.bfc,
          ),
          node = child,
          parent = blockPos,
        )

        cursor.y += marginTop + child.dimensions.y + marginBottom

        cursor.x = borderWidth + padLeft

        maxLineWidth =
          max(maxLineWidth, child.dimensions.x + marginLeft + padRight + borderWidth)

    if node.display == DisplayMode.Inline:
      node.dimensions.x = maxLineWidth
    else:
      node.dimensions.x = layoutWidth

    node.dimensions.y = cursor.y + currLineHeight + padBottom + borderWidth

  if *explicitHeight:
    node.dimensions.y = &explicitHeight + padTop + padBottom + (borderWidth * 2.0'f32)
