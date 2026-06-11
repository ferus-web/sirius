## Flow layout implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, tables]
import
  components/style/types,
  components/dom/[dom, tags],
  components/layout/[output_manager, types]
import pkg/[chronicles, shakar, vmath]

logScope:
  topics = "layout/flow"

proc resolveMargin*(
    value: Option[CSSValue], availableWidth: float32, outputManager: OutputManager
): float32 =
  if !value:
    return 0.0'f32

  let value = &value
  case value.kind
  of CSSValueKind.Dimension:
    return outputManager.computePixels(value, relativeBase = availableWidth)
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

proc computeLayout*(
    node: LayoutNode,
    parent: vmath.Vec2,
    availableWidth: float32,
    outputManager: OutputManager,
    parentExplicitHeight: Option[float32] = none(float32),
) =
  node.absolutePos = parent

  let isImage =
    node.domNode != nil and node.domNode of tags.HTMLImageElement and
    Element(node.domNode).tagType() == TAG_IMG

  if isImage:
    let element = HTMLImageElement(node.domNode)
    if node.imageContent != nil:
      let img = node.imageContent
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

  let
    padTop = resolveMargin(node.padding.top, availableWidth, outputManager)
    padBottom = resolveMargin(node.padding.bottom, availableWidth, outputManager)
    padLeft = resolveMargin(node.padding.left, availableWidth, outputManager)
    padRight = resolveMargin(node.padding.right, availableWidth, outputManager)

    explicitWidth =
      if *node.width:
        some(outputManager.computePixels(&node.width, relativeBase = availableWidth))
      else:
        none(float32)

    explicitHeight =
      if *node.height and *parentExplicitHeight:
        some(
          outputManager.computePixels(
            &node.height, relativeBase = &parentExplicitHeight
          )
        )
      else:
        none(float32)

    layoutWidth =
      if *explicitWidth:
        &explicitWidth + padLeft + padRight
      else:
        availableWidth

  var hasInline = false
  for child in node.children:
    if child.display in {DisplayMode.Anonymous, DisplayMode.Inline}:
      hasInline = true
      break

  if not hasInline:
    node.dimensions = vec2(layoutWidth, padTop)

    for child in node.children:
      let
        marginTop = resolveMargin(child.margins.top, layoutWidth, outputManager)
        marginBottom = resolveMargin(child.margins.bottom, layoutWidth, outputManager)
        marginLeft = resolveMargin(child.margins.left, layoutWidth, outputManager)
        marginRight = resolveMargin(child.margins.right, layoutWidth, outputManager)

        childAvailableWidth =
          node.dimensions.x - padLeft - padRight - marginLeft - marginRight

      let cpos = vec2(
        node.absolutePos.x + padLeft + marginLeft,
        node.absolutePos.y + node.dimensions.y + marginTop,
      )
      computeLayout(child, cpos, childAvailableWidth, outputManager, explicitHeight)
      node.dimensions.y += marginTop + child.dimensions.y + marginBottom

    node.dimensions.y += padBottom
  else:
    node.dimensions.x = 0'f32

    var cursor = vec2(padLeft, padTop)
    var currLineHeight: float32
    var maxLineWidth: float32

    let innerAvailableWidth = layoutWidth - padLeft - padRight

    for child in node.children:
      if child.display == DisplayMode.Anonymous:
        let
          fontSize = computePixels(outputManager, &child.fontSize)
          lineHeight = resolveLineHeight(child.lineHeight, fontSize, outputManager)

        child.dimensions = vec2(
          float32(child.content.len) * (fontSize * 0.55'f32),
            # HACK: Estimate the character width at 55% of the height
          fontSize,
        ) # TODO: Proper text bounds measuring

        if cursor.x + child.dimensions.x > (layoutWidth - padRight) and
            cursor.x > padLeft:
          cursor.x = padLeft
          cursor.y += currLineHeight
          currLineHeight = 0.0'f32

        let halfLeading = (lineHeight - fontSize) * 0.5'f32

        child.absolutePos.x = node.absolutePos.x + cursor.x
        child.absolutePOs.y = node.absolutePos.y + cursor.y + halfLeading

        cursor.x += child.dimensions.x
        currLineHeight = max(currLineHeight, lineHeight)
        maxLineWidth = max(maxLineWidth, cursor.x + padRight)
      elif child.display == DisplayMode.Inline:
        computeLayout(
          child,
          vec2(node.absolutePos.x + cursor.x, node.absolutePos.y + cursor.y),
          layoutWidth - cursor.x - padRight,
          outputManager,
          explicitHeight,
        )

        let lineHeight =
          resolveLineHeight(child.lineHeight, child.dimensions.y, outputManager)

        cursor.x += child.dimensions.x
        currLineHeight = max(currLineHeight, lineHeight)
        maxLineWidth = max(maxLineWidth, cursor.x + padRight)
      elif child.display == DisplayMode.Block:
        if cursor.x > padLeft:
          # If we had some text before this block elem inside the inline parent
          # then we need to force a line break.
          cursor.x = padLeft
          cursor.y += currLineHeight
          currLineHeight = 0'f32

        let
          marginTop = resolveMargin(child.margins.top, layoutWidth, outputManager)
          marginBottom = resolveMargin(child.margins.bottom, layoutWidth, outputManager)
          marginLeft = resolveMargin(child.margins.left, layoutWidth, outputManager)

          blockPos = vec2(
            node.absolutePos.x + padLeft + marginLeft,
            node.absolutePos.y + cursor.y + marginTop,
          )

        computeLayout(
          child,
          blockPos,
          innerAvailableWidth - marginLeft,
          outputManager,
          explicitHeight,
        )

        cursor.y += marginTop + child.dimensions.y + marginBottom
        maxLineWidth =
          max(maxLineWidth, child.dimensions.x + padLeft + marginLeft + padRight)

    if node.display == DisplayMode.Inline:
      node.dimensions.x = maxLineWidth
    else:
      node.dimensions.x = layoutWidth

    node.dimensions.y = cursor.y + currLineHeight + padBottom

  if *explicitHeight:
    node.dimensions.y = &explicitHeight + padTop + padBottom
