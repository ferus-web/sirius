## Types for the layout engine
## 
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options
import pkg/vmath
import components/html/dom, components/style/types, components/os/fonts

type
  DisplayMode* {.pure, size: sizeof(uint8).} = enum
    ## Layout mode
    Block
    Inline
    Anonymous

  LayoutMargins* = object
    top*, right*, bottom*, left*: Option[CSSValue]

  LayoutNode* = ref object
    domNode*: dom.Node ## The associated DOM node with this element
    children*: seq[LayoutNode]

    display*: DisplayMode ## `display` attribute taken from computed style
    margins*: LayoutMargins
    fontFamily*: Font
    fontSize*: Option[CSSValue]

    style*: ComputedStyle ## The computed style of the associated DOM node
    content*: string ## Any text content

    relativePos*, absolutePos*: vmath.Vec2
    dimensions*: vmath.Vec2

proc clone*(node: LayoutNode): LayoutNode =
  result = new(LayoutNode)
  result.domNode = node.domNode

  result.children = newSeqOfCap[LayoutNode](node.children.len)
  for child in node.children:
    result.children &= clone(child)

  result.display = node.display
  result.margins = node.margins
  result.fontFamily = node.fontFamily
  result.fontSize = node.fontSize
  result.style = node.style
  result.content = node.content

  result.relativePos = node.relativePos
  result.absolutePos = node.absolutePos
  result.dimensions = node.dimensions
