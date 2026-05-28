## Routines for turning the DOM and computed styles into a layout tree
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, sequtils, strformat, strutils, tables]
import
  components/html/[dom, dom_utils],
  components/style/types,
  components/layout/types,
  components/os/fonts
import pkg/[chronicles, results, shakar]
import pretty

logScope:
  topics = "layout/node_builder"

const
  DisplayAttr = "display"
  FontSizeAttr = "font-size"
  FontFamilyAttr = "font-family"

  MarginBottomAttr = "margin-bottom"
  MarginTopAttr = "margin-top"
  MarginLeftAttr = "margin-left"
  MarginRightAttr = "margin-right"
  MarginAttr = "margin"

func cleanFontFamily(family: CSSValue): string =
  ## Clean up the font-family attribute so fontconfig can easily parse it internally.
  # TODO: This routine doesn't belong here.

  case family.kind
  of CSSValueKind.String:
    return family.str
  of CSSValueKind.List:
    return family.list.mapIt(it.str).join(",")
  else:
    discard

proc applyMarginAttr(layoutNode: LayoutNode, prop: CSSValue): Result[void, string] =
  if prop.kind == CSSValueKind.Dimension:
    let value = some(prop)
    layoutNode.margins =
      LayoutMargins(top: value, bottom: value, left: value, right: value)
  elif prop.kind == CSSValueKind.List:
    case prop.list.len
    of 1:
      unreachable
    of 2:
      let
        horiz = some(prop.list[0])
        vert = some(prop.list[1])
      layoutNode.margins =
        LayoutMargins(top: vert, bottom: vert, left: horiz, right: horiz)
    of 3:
      layoutNode.margins = LayoutMargins(
        top: some(prop.list[0]),
        left: some(prop.list[1]),
        right: some(prop.list[1]),
        bottom: some(prop.list[2]),
      )
    of 4:
      layoutNode.margins = LayoutMargins(
        top: some(prop.list[0]),
        right: some(prop.list[1]),
        bottom: some(prop.list[2]),
        left: some(prop.list[3]),
      )
    else:
      return err(
        &"Property 'margin' expects four values at most, got {prop.list.len} values instead."
      )
  else:
    return err(
      &"Property 'margin' expects dimension or list of dimensions, got {prop.kind} instead."
    )

proc setStyleProperties(layoutNode: LayoutNode, fontProvider: FontProvider) =
  for attr, prop in layoutNode.style:
    if attr == DisplayAttr and layoutNode.display != DisplayMode.Anonymous:
      if prop.kind != CSSValueKind.String:
        warn "Ignoring display property, expected String.", got = prop.kind
      else:
        layoutNode.display = (
          if prop.str == "block":
            DisplayMode.Block
          elif prop.str == "inline":
            DisplayMode.Inline
          else:
            warn "Unhandled display property for node", display = prop
            DisplayMode.Block
        )
    elif attr == FontSizeAttr:
      layoutNode.fontSize = some(prop)
    elif attr == MarginBottomAttr:
      layoutNode.margins.bottom = some(prop)
    elif attr == "--sirius-noop":
      continue
    elif attr == FontFamilyAttr:
      layoutNode.fontFamily = &fontProvider.getFontByFamily(cleanFontFamily(prop))
        # TODO: Handle fallbacks
    elif attr == MarginTopAttr:
      layoutNode.margins.top = some(prop)
    elif attr == MarginLeftAttr:
      layoutNode.margins.left = some(prop)
    elif attr == MarginRightAttr:
      layoutNode.margins.right = some(prop)
    elif attr == MarginAttr:
      if (let warning = applyMarginAttr(layoutNode, prop); *warning):
        warn "Styling warning", msg = warning.error()

proc createLayoutNode*(
    node: dom.Node, style: StyleMap, fontProvider: FontProvider
): LayoutNode =
  let layoutNode = LayoutNode(domNode: node)

  if node of dom.Text:
    let textData = Text(node).data
    if textData.len < 1 or isEmptyOrWhitespace(textData):
      return

    layoutNode.content = textData
    layoutNode.display = DisplayMode.Anonymous
    return layoutNode

  if node in style:
    # If we have a style for the DOM node, we can apply it to the layout node
    layoutNode.style = style[node]
    setStyleProperties(layoutNode, fontProvider)
  else:
    if node of dom.Element:
      warn "Element doesn't have defined style, it'll probably either render badly or not at all.",
        tag = Element(node).tagType

  ensureMove(layoutNode)

proc propagateStyles*(node: LayoutNode, style: StyleMap, fontProvider: FontProvider) =
  if node == nil:
    return

  setStyleProperties(node, fontProvider)

  for child in node.children:
    if child.display == DisplayMode.Anonymous:
      # Make anonymous nodes inherit their parent's style
      child.style = node.style

    propagateStyles(child, style, fontProvider)

proc buildLayoutTree*(
    node: dom.Node, style: StyleMap, fontProvider: FontProvider
): LayoutNode =
  let currentLayout = createLayoutNode(node, style, fontProvider)
  # if currentLayout != nil:
  #  setStyleProperties(currentLayout)

  for child in node.childList:
    if child of dom.Comment:
      continue

    if child of dom.Element:
      let tag = Element(child).tagType
      if tag in [TAG_SCRIPT, TAG_STYLE, TAG_HEAD]:
        continue

    let childLayout = buildLayoutTree(child, style, fontProvider)
    if childLayout != nil:
      currentLayout.children &= childLayout

  # setStyleProperties(currentLayout)
  currentLayout
