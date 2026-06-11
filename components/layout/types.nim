## Types for the layout engine
## 
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options
import pkg/[chroma, pixie, vmath]
import
  components/dom/dom, components/style/types, components/os/fonts, components/css/types

type
  DisplayMode* {.pure, size: sizeof(uint8).} = enum
    ## Layout mode
    Block
    Inline
    Anonymous

  LayoutMargins* = object
    top*, right*, bottom*, left*: Option[CSSValue]

  LayoutPadding* = object
    top*, right*, bottom*, left*: Option[CSSValue]

  LayoutNode* = ref object
    domNode*: dom.Node ## The associated DOM node with this element
    children*: seq[LayoutNode]

    display*: DisplayMode ## `display` attribute taken from computed style
    margins*: LayoutMargins
    padding*: LayoutPadding
    fontFamily*: fonts.Font
    cursor*: Option[string]
    fontSize*: Option[CSSValue]
    color*, backgroundColor*: chroma.ColorRGBA
    lineHeight*: Option[CSSValue]
    textDecoration*: TextDecoration

    style*: ComputedStyle ## The computed style of the associated DOM node
    content*: string ## Any text content
    imageContent*: pixie.Image ## Any image content

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
  result.color = node.color
  result.cursor = node.cursor
  result.backgroundColor = node.backgroundColor
  result.style = node.style
  result.content = node.content
  result.imageContent = node.imageContent
  result.lineHeight = node.lineHeight
  result.padding = node.padding
  result.textDecoration = node.textDecoration

  result.relativePos = node.relativePos
  result.absolutePos = node.absolutePos
  result.dimensions = node.dimensions
