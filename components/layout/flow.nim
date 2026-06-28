## Flow layout implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[hashes, options, tables]
import
  components/style/types,
  components/css/types,
  components/dom/[dom, tags],
  components/layout/[output_manager, types],
  components/os/fonts
import pkg/[bumpy, chronicles, shakar, vmath]

logScope:
  topics = "layout/flow"

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

# TODO: Should probably move all of these arguments into a singular `FlowContext` or a more generic `LayoutEngine` eventually
proc computeLayout*(
    node: LayoutNode,
    parent: vmath.Vec2,
    availableWidth: float32,
    outputManager: OutputManager,
    fontProvider: FontProvider,
    parentExplicitHeight: Option[float32] = none(float32),
) =
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

    if node.display == DisplayMode.Block and node.dimensions.x > availableWidth:
      let ratio = availableWidth / node.dimensions.x
      node.dimensions = vec2(availableWidth, node.dimensions.y * ratio)
    return

  if isInput:
    let element = HTMLInputElement(node.domNode)

    let fSize = computePixels(outputManager, &node.fontSize, fontSize = 16'f32)

    let
      intrinsicWidth =
        if !node.width:
          20.0'f32 * (fSize * 0.65'f32)
        else:
          outputManager.computePixels(&node.width, relativeBase = availableWidth)
      intrinsicHeight =
        if !node.height:
          fSize * 1.2'f32
        else:
          outputManager.computePixels(
            &node.height,
            relativeBase = (if *parentExplicitHeight: &parentExplicitHeight
            else: 0'f32),
          )

    if node.dimensions.x == 0'f32:
      node.dimensions.x = intrinsicWidth
    if node.dimensions.y == 0'f32:
      node.dimensions.y = intrinsicHeight

    if node.display == DisplayMode.Block and node.dimensions.x > availableWidth:
      node.dimensions.x = availableWidth

    return

  let
    borderWidth =
      if *node.border.width and *node.border.style and
          (&node.border.style) != BorderStyle.None:
        computePixels(outputManager, &node.border.width)
      else:
        0.0'f32

    fontSize = computePixels(outputManager, &node.fontSize, fontSize = 16'f32)
    padTop = resolveMargin(node.padding.top, availableWidth, outputManager, fontSize)
    padBottom =
      resolveMargin(node.padding.bottom, availableWidth, outputManager, fontSize)
    padLeft = resolveMargin(node.padding.left, availableWidth, outputManager, fontSize)
    padRight =
      resolveMargin(node.padding.right, availableWidth, outputManager, fontSize)

    explicitWidth =
      if *node.width:
        some(outputManager.computePixels(&node.width, relativeBase = availableWidth))
      else:
        none(float32)

    explicitHeight =
      if *node.height:
        some(
          outputManager.computePixels(
            &node.height,
            relativeBase = (if *parentExplicitHeight: &parentExplicitHeight
            else: 0'f32),
          )
        )
      else:
        none(float32)

    layoutWidth =
      if *explicitWidth:
        &explicitWidth + padLeft + padRight + (borderWidth * 2.0'f32)
      else:
        availableWidth

  var leftFloats, rightFloats: seq[Rect]

  proc getLineBounds(y: float32): tuple[left, right: float32] =
    var bounds =
      (left: borderWidth + padLeft, right: layoutWidth - borderWidth - padRight)
    for f in leftFloats:
      if y >= f.y and y < (f.y + f.h):
        bounds.left = max(bounds.left, f.x + f.w)

    for f in rightFloats:
      if y >= f.y and y < (f.y + f.h):
        bounds.right = min(bounds.right, f.x)

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
        fontSize = computePixels(outputManager, &child.fontSize, fontSize = 16'f32)
          # FIXME: Not compliant.
        marginTop =
          resolveMargin(child.margins.top, layoutWidth, outputManager, fontSize)
        marginBottom =
          resolveMargin(child.margins.bottom, layoutWidth, outputManager, fontSize)
        marginLeft =
          resolveMargin(child.margins.left, layoutWidth, outputManager, fontSize)
        marginRight =
          resolveMargin(child.margins.right, layoutWidth, outputManager, fontSize)

      if child.floatMode in {FloatMode.Left, FloatMode.Right}:
        let bounds = getLineBounds(currentY)
        let floatWidth = bounds.right - bounds.left - marginLeft - marginRight

        let fPos = vec2(
          node.absolutePos.x + bounds.left + marginLeft,
          node.absolutePos.y + currentY + marginTop,
        )
        computeLayout(
          child, fPos, floatWidth, outputManager, fontProvider, explicitHeight
        )

        if child.floatMode == FloatMode.Left:
          child.absolutePos.x = node.absolutePos.x + bounds.left + marginLeft
          leftFloats.add(
            rect(
              bounds.left,
              currentY,
              child.dimensions.x + marginLeft + marginRight,
              child.dimensions.y + marginTop + marginBottom,
            )
          )
        else:
          let rEdge = bounds.right - child.dimensions.x - marginRight
          child.absolutePos.x = node.absolutePos.x + rEdge
          rightFloats.add(
            rect(
              rEdge,
              currentY,
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
        child, cpos, childAvailableWidth, outputManager, fontProvider, explicitHeight
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
        marginTop = resolveMargin(child.margins.top, layoutWidth, outputManager)
        marginBottom = resolveMargin(child.margins.bottom, layoutWidth, outputManager)
        marginLeft = resolveMargin(child.margins.left, layoutWidth, outputManager)
        marginRight = resolveMargin(child.margins.right, layoutWidth, outputManager)

      if child.floatMode in {FloatMode.Left, FloatMode.Right}:
        let bounds = getLineBounds(cursor.y)
        let floatWidth = bounds.right - bounds.left - marginLeft - marginRight

        let fPos = vec2(
          node.absolutePos.x + bounds.left + marginLeft,
          node.absolutePos.y + cursor.y + marginTop,
        )
        computeLayout(
          child, fPos, floatWidth, outputManager, fontProvider, explicitHeight
        )

        if child.floatMode == FloatMode.Left:
          child.absolutePos.x = node.absolutePos.x + bounds.left + marginLeft
          child.absolutePos.y = node.absolutePos.y + cursor.y + marginTop
          leftFloats.add(
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
          rightFloats.add(
            rect(
              rEdge,
              cursor.y,
              child.dimensions.x + marginLeft + marginRight,
              child.dimensions.y + marginTop + marginBottom,
            )
          )
        continue

      if child.display == DisplayMode.Anonymous:
        let
          fontSize = computePixels(outputManager, &child.fontSize, fontSize = 16'f32)
          lineHeight = resolveLineHeight(child.lineHeight, fontSize, outputManager)

        processTextContent(child.content, node.whitespace)

        child.arrangement = fontProvider.loader.measureTextBounds(
          child.fontFamily, vec2(innerAvailableWidth, fontSize), fontSize, child.content
        )
        child.dimensions =
          vec2(child.arrangement.bounding.w, child.arrangement.bounding.h)

        var bounds = getLineBounds(cursor.y)
        if cursor.x < bounds.left:
          cursor.x = bounds.left

        if cursor.x + child.dimensions.x > bounds.right and cursor.x > bounds.left:
          cursor.y += max(currLineHeight, fontSize)
          currLineHeight = 0.0'f32
          bounds = getLineBounds(cursor.y)
          cursor.x = bounds.left

        let halfLeading = (lineHeight - fontSize) * 0.5'f32

        child.absolutePos.x = node.absolutePos.x + cursor.x
        child.absolutePos.y = node.absolutePos.y + cursor.y + halfLeading

        cursor.x += child.dimensions.x
        currLineHeight = max(currLineHeight, max(lineHeight, child.dimensions.y))
        maxLineWidth = max(maxLineWidth, cursor.x + padRight + borderWidth)
      elif child.display == DisplayMode.Inline:
        var bounds = getLineBounds(cursor.y)
        if cursor.x < bounds.left:
          cursor.x = bounds.left

        computeLayout(
          child,
          vec2(node.absolutePos.x + cursor.x, node.absolutePos.y + cursor.y),
          bounds.right - cursor.x,
          outputManager,
          fontProvider,
          explicitHeight,
        )

        let lineHeight =
          resolveLineHeight(child.lineHeight, child.dimensions.y, outputManager)
        cursor.x += child.dimensions.x
        currLineHeight = max(currLineHeight, max(lineHeight, child.dimensions.y))
        maxLineWidth = max(maxLineWidth, cursor.x + padRight + borderWidth)
      elif child.display == DisplayMode.Block:
        var bounds = getLineBounds(cursor.y)
        if cursor.x > bounds.left:
          cursor.y += currLineHeight
          currLineHeight = 0'f32
          bounds = getLineBounds(cursor.y)
          cursor.x = bounds.left

        let blockPos = vec2(
          node.absolutePos.x + bounds.left + marginLeft,
          node.absolutePos.y + cursor.y + marginTop,
        )

        computeLayout(
          child,
          blockPos,
          bounds.right - bounds.left - marginLeft - marginRight,
          outputManager,
          fontProvider,
          explicitHeight,
        )

        cursor.y += marginTop + child.dimensions.y + marginBottom
        bounds = getLineBounds(cursor.y)
        cursor.x = bounds.left
        maxLineWidth = max(
          maxLineWidth,
          child.dimensions.x + bounds.left + marginLeft + padRight + borderWidth,
        )

    if node.display == DisplayMode.Inline:
      node.dimensions.x = maxLineWidth
    else:
      node.dimensions.x = layoutWidth

    node.dimensions.y = cursor.y + currLineHeight + padBottom + borderWidth

  if *explicitHeight:
    node.dimensions.y = &explicitHeight + padTop + padBottom + (borderWidth * 2.0'f32)
