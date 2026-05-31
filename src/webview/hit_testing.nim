## Hit testing implementation.
## I mostly intend to make this similar to the equivalent web APIs just to make my life easier.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[algorithm, options]
import components/layout/types, components/html/dom
import ./types
import pkg/[shakar, vmath]

proc hitTest*(view: WebView, node: LayoutNode, pos: vmath.Vec2): Option[LayoutNode] =
  let
    nodePos = view.renderCtx.viewerPosition + pos
    hasToBeIgnored =
      node.domNode != nil and node.domNode of dom.Element and
      Element(node.domNode).tagType() in {TAG_HTML, TAG_BODY}

  if hasToBeIgnored or (
    pos.x < nodePos.x or pos.x > (nodePos.x + node.dimensions.x) or pos.y < nodePos.y or
    pos.y > (nodePos.y + node.dimensions.y)
  ):
    for child in reversed(node.children):
      let res = hitTest(view, child, pos)
      if *res:
        return res

    return none(LayoutNode)

  some(node)
