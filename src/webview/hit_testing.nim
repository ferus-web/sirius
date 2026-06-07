## Hit testing implementation.
## I mostly intend to make this similar to the equivalent web APIs just to make my life easier.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options]
import components/layout/types, components/dom/dom
import ./types
import pkg/[bumpy, shakar, vmath]

proc hitTest*(view: WebView, node: LayoutNode, pos: vmath.Vec2): Option[LayoutNode] =
  proc walk(node: LayoutNode): Option[LayoutNode] =
    let nodeSpatial = rect(
      pos = view.renderCtx.viewerPosition + node.absolutePos, size = node.dimensions
    )

    if pos.overlaps(nodeSpatial):
      for child in node.children:
        if not (child.domNode of dom.Element):
          continue

        let res = walk(child)
        if *res:
          return res

      return some(node)

  walk(node)
