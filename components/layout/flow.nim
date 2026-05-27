## Flow layout implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, tables]
import
  components/style/types, components/html/dom, components/layout/[output_manager, types]
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
    case value.dim.unit
    of CSSUnit.Percent:
      # not reachable yet, but eh
      return (value.dim.value / 100'f32) * availableWidth
    else:
      return outputManager.computePixels(value)
  of CSSValueKind.Integer:
    return float32(value.num)
  else:
    # warn "Unhandled type for margin property", got = value.kind
    return 0.0'f32

proc computeLayout*(
    node: LayoutNode,
    parent: vmath.Vec2,
    availableWidth: float32,
    outputManager: OutputManager,
) =
  node.absolutePos = parent

  var hasInline = false
  for child in node.children:
    if child.display in {DisplayMode.Anonymous, DisplayMode.Inline}:
      hasInline = true
      break

  if not hasInline:
    node.dimensions.x = availableWidth

    for child in node.children:
      let
        marginTop = resolveMargin(child.margins.top, availableWidth, outputManager)
        marginBottom =
          resolveMargin(child.margins.bottom, availableWidth, outputManager)
        marginLeft = resolveMargin(child.margins.left, availableWidth, outputManager)
        marginRight = resolveMargin(child.margins.right, availableWidth, outputManager)

        childAvailableWidth = node.dimensions.x - marginLeft - marginRight

      let cpos = vec2(
        node.absolutePos.x + marginLeft,
        node.absolutePos.y + node.dimensions.y + marginTop,
      )
      computeLayout(child, cpos, childAvailableWidth, outputManager)
      node.dimensions.y += marginTop + child.dimensions.y + marginBottom
  else:
    node.dimensions.x = 0'f32

    var cursor: vmath.Vec2
    var currLineHeight: float32
    var maxLineWidth: float32

    for child in node.children:
      if child.display == DisplayMode.Anonymous:
        let fontSize = computePixels(outputManager, &child.fontSize)
        child.dimensions = vec2(
          float32(child.content.len) * (fontSize * 0.55'f32),
            # HACK: Estimate the character width at 55% of the height
          fontSize,
        ) # TODO: Proper text bounds measuring

        if cursor.x + child.dimensions.x > availableWidth and cursor.x > 0'f32:
          cursor.x = 0.0'f32
          cursor.y += currLineHeight
          currLineHeight = 0.0'f32

        child.absolutePos.x = node.absolutePos.x + cursor.x
        child.absolutePOs.y = node.absolutePos.y + cursor.y

        cursor.x += child.dimensions.x
        currLineHeight = max(currLineHeight, child.dimensions.y)
        maxLineWidth = max(maxLineWidth, cursor.x)
      elif child.display == DisplayMode.Inline:
        computeLayout(
          child,
          vec2(node.absolutePos.x + cursor.x, node.absolutePos.y + cursor.y),
          availableWidth - cursor.x,
          outputManager,
        )
        cursor.x += child.dimensions.x
        currLineHeight = max(currLineHeight, child.dimensions.y)
        maxLineWidth = max(maxLineWidth, cursor.x)
      elif child.display == DisplayMode.Block:
        if cursor.x > 0'f32:
          # If we had some text before this block elem inside the inline parent
          # then we need to force a line break.
          cursor.x = 0'f32
          cursor.y += currLineHeight
          currLineHeight = 0'f32

        let
          marginTop = resolveMargin(child.margins.top, availableWidth, outputManager)
          marginBottom =
            resolveMargin(child.margins.bottom, availableWidth, outputManager)
          marginLeft = resolveMargin(child.margins.left, availableWidth, outputManager)

          blockPos = vec2(
            node.absolutePos.x + marginLeft, node.absolutePos.y + cursor.y + marginTop
          )

        computeLayout(child, blockPos, availableWidth - marginLeft, outputManager)

        cursor.y += marginTop + child.dimensions.y + marginBottom
        maxLineWidth = max(maxLineWidth, child.dimensions.x + marginLeft)

    if node.display == DisplayMode.Inline:
      node.dimensions.x = maxLineWidth

    node.dimensions.y = cursor.y + currLineHeight
