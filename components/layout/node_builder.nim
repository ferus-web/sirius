## Routines for turning the DOM and computed styles into a layout tree
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, sequtils, strutils, tables]
import
  components/html/[dom, dom_utils],
  components/style/types,
  components/layout/types,
  components/os/fonts
import pkg/[chronicles, shakar]
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
