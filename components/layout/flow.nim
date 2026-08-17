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
    return outputManager.computePixels(value)
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
    let element = HTMLInputElement(node.domNode)

    let fSize = computePixels(ctx.outputManager, &node.fontSize, fontSize = 16'f32)

    let
      intrinsicWidth =
        if !node.width:
          20.0'f32 * (fSize * 0.65'f32)
        else:
          ctx.outputManager.computePixels(
            &node.width, relativeBase = ctx.availableWidth
          )
      intrinsicHeight =
        if !node.height:
          fSize * 1.2'f32
        else:
          ctx.outputManager.computePixels(
            &node.height,
            relativeBase =
              (if *ctx.parentExplicitHeight: &ctx.parentExplicitHeight
              else: 0'f32),
          )

    if node.dimensions.x == 0'f32:
      node.dimensions.x = intrinsicWidth
    if node.dimensions.y == 0'f32:
      node.dimensions.y = intrinsicHeight

    if node.display == DisplayMode.Block and node.dimensions.x > ctx.availableWidth:
      node.dimensions.x = ctx.availableWidth

    return

  let
    borderWidth =
      if *node.border.width and *node.border.style and
          (&node.border.style) != BorderStyle.None:
        computePixels(ctx.outputManager, &node.border.width)
      else:
        0.0'f32

    fontSize = computePixels(ctx.outputManager, &node.fontSize, fontSize = 16'f32)
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
            &node.width, relativeBase = ctx.availableWidth
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
          )
        )
      else:
        none(float32)

    layoutWidth =
      if *explicitWidth:
        &explicitWidth + padLeft + padRight + (borderWidth * 2.0'f32)
      else:
        ctx.availableWidth

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

  var hasInline = false
  for child in node.children:
    if child.display in {DisplayMode.Anonymous, DisplayMode.Inline}:
      hasInline = true
      break

  if not hasInline:
    node.dimensions = vec2(layoutWidth, borderWidth + padTop)
    var currentY = borderWidth + padTop

    for child in node.children:
      let
        fontSize = computePixels(ctx.outputManager, &child.fontSize, fontSize = 16'f32)
          # FIXME: Not compliant.
        marginTop =
          resolveMargin(child.margins.top, layoutWidth, ctx.outputManager, fontSize)
        marginBottom =
          resolveMargin(child.margins.bottom, layoutWidth, ctx.outputManager, fontSize)
        marginLeft =
          resolveMargin(child.margins.left, layoutWidth, ctx.outputManager, fontSize)
        marginRight =
          resolveMargin(child.margins.right, layoutWidth, ctx.outputManager, fontSize)

      if child.floatMode in {FloatMode.Left, FloatMode.Right}:
        let bounds = getLineBounds(currentY)
        let floatWidth = bounds.right - bounds.left - marginLeft - marginRight

        let fPos = vec2(
          node.absolutePos.x + bounds.left + marginLeft,
          node.absolutePos.y + currentY + marginTop,
        )
        computeLayout(
          FlowContext(
            document: ctx.document,
            availableWidth: floatWidth,
            outputManager: ctx.outputManager,
            fontProvider: ctx.fontProvider,
            parentExplicitHeight: explicitHeight,
            bfc:
              if child.floatMode != FloatMode.None:
                BlockFloatingContext()
              else:
                ctx.bfc,
          ),
          node = child,
          parent = fPos,
        )

        if child.floatMode == FloatMode.Left:
          child.absolutePos.x = node.absolutePos.x + bounds.left + marginLeft
          ctx.bfc.leftFloats.add(
            rect(
              child.absolutePos.x - marginLeft,
              child.absolutePos.y - marginTop,
              child.dimensions.x + marginLeft + marginRight,
              child.dimensions.y + marginTop + marginBottom,
            )
          )
        else:
          let rEdge = bounds.right - child.dimensions.x - marginRight
          child.absolutePos.x = node.absolutePos.x + rEdge
          ctx.bfc.rightFloats.add(
            rect(
              child.absolutePos.x - marginLeft,
              child.absolutePos.y - marginTop,
              child.dimensions.x + marginLeft + marginRight,
              child.dimensions.y + marginTop + marginBottom,
            )
          )
        continue

      let childAvailableWidth =
        layoutWidth - (borderWidth * 2.0'f32) - padLeft - padRight - marginLeft -
        marginRight
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
          bfc:
            if child.floatMode != FloatMode.None:
              BlockFloatingContext()
            else:
              ctx.bfc,
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
    let innerAvailableWidth = layoutWidth - (borderWidth * 2.0'f32) - padLeft - padRight

    for child in node.children:
      let
        marginTop = resolveMargin(child.margins.top, layoutWidth, ctx.outputManager)
        marginBottom =
          resolveMargin(child.margins.bottom, layoutWidth, ctx.outputManager)
        marginLeft = resolveMargin(child.margins.left, layoutWidth, ctx.outputManager)
        marginRight = resolveMargin(child.margins.right, layoutWidth, ctx.outputManager)

      if child.floatMode in {FloatMode.Left, FloatMode.Right}:
        let bounds = getLineBounds(cursor.y)
        let floatWidth = bounds.right - bounds.left - marginLeft - marginRight

        let fPos = vec2(
          node.absolutePos.x + bounds.left + marginLeft,
          node.absolutePos.y + cursor.y + marginTop,
        )
        computeLayout(
          FlowContext(
            document: ctx.document,
            outputManager: ctx.outputManager,
            fontProvider: ctx.fontProvider,
            availableWidth: floatWidth,
            parentExplicitHeight: explicitHeight,
            bfc:
              if child.floatMode != FloatMode.None:
                BlockFloatingContext()
              else:
                ctx.bfc,
          ),
          node = child,
          parent = fPos,
        )

        if child.floatMode == FloatMode.Left:
          child.absolutePos.x = node.absolutePos.x + bounds.left + marginLeft
          child.absolutePos.y = node.absolutePos.y + cursor.y + marginTop
          ctx.bfc.leftFloats.add(
            rect(
              bounds.left,
              cursor.y,
              child.dimensions.x + marginLeft + marginRight,
              child.dimensions.y + marginTop + marginBottom,
            )
          )
          cursor.x =
            max(cursor.x, bounds.left + child.dimensions.x + marginLeft + marginRight)
        else:
          let rEdge = bounds.right - child.dimensions.x - marginRight
          child.absolutePos.x = node.absolutePos.x + rEdge
          child.absolutePos.y = node.absolutePos.y + cursor.y + marginTop
          ctx.bfc.rightFloats.add(
            rect(
              rEdge,
              cursor.y,
              child.dimensions.x + marginLeft + marginRight,
              child.dimensions.y + marginTop + marginBottom,
            )
          )
        continue

      if child.display == DisplayMode.Anonymous:
        child.textRuns.setLen(0)

        let
          fontSize =
            computePixels(ctx.outputManager, &child.fontSize, fontSize = 16'f32)
          lineHeight = resolveLineHeight(child.lineHeight, fontSize, ctx.outputManager)

        let words = child.content.split()
        let spaceArrangement = ctx.fontProvider.loader.measureTextBounds(
          child.fontFamily,
          vec2(
            99999'f32, 999999'f32 #[ FIXME ]#
          ),
          fontSize,
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
            fontSize,
            TextAlignment.Left,
            none(string),
            word,
          )

          if cursor.x + wordArr.bounding.w > bounds.right and cursor.x > bounds.left:
            alignCurrLine(child, cast[uint](child.textRuns.len), cursor.x, bounds.right)

            cursor.y += max(currLineHeight, lineHeight)
            currLineHeight = 0.0'f32

            bounds = getLineBounds(cursor.y)
            cursor.x = bounds.left

          let halfLeading = (lineHeight - fontSize) * 0.5'f32
          let wordPos = vec2(cursor.x, cursor.y + halfLeading)

          child.textRuns &= TextRun(pos: wordPos, arrangement: wordArr)

          cursor.x += wordArr.bounding.w + spaceWidth
          currLineHeight = max(currLineHeight, max(lineHeight, wordArr.bounding.h))
          maxLineWidth = max(maxLineWidth, cursor.x + padRight + borderWidth)

        alignCurrLine(child, cast[uint](child.textRuns.len), cursor.x, bounds.right)

        child.dimensions = vec2(maxLineWidth, cursor.y + currLineHeight)
        child.absolutePos = node.absolutePos
      elif child.display == DisplayMode.Inline:
        var bounds = getLineBounds(cursor.y)
        if cursor.x < bounds.left:
          cursor.x = bounds.left

        computeLayout(
          FlowContext(
            document: ctx.document,
            outputManager: ctx.outputManager,
            fontProvider: ctx.fontProvider,
            availableWidth: bounds.right - cursor.x,
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

        let lineHeight =
          resolveLineHeight(child.lineHeight, child.dimensions.y, ctx.outputManager)
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

        let childAvailableWidth = innerAvailableWidth - marginLeft - marginRight

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
