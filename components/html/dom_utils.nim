## Utility routines mostly related to DOM traversal
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[hashes, options, strutils]
import components/dom/dom
import pkg/shakar

func hash*(node: dom.Node): hashes.Hash {.inline.} =
  hash(cast[pointer](node))

func html*(doc: dom.Document): Option[dom.Element] =
  for child in doc.childList:
    if child of dom.Element and Element(child).tagType() == TAG_HTML:
      return some(Element(child))

func getAttr*(
    element: dom.Element, factory: dom.AtomFactory, attribKey: string
): Option[string] {.inline.} =
  for attr in element.attrs:
    if atomToStr(factory, attr.name) == attribKey:
      return some(attr.value)

  none(string)

func getIntAttr*(
    element: dom.Element, factory: dom.AtomFactory, attribKey: string
): Option[int] =
  let attr = getAttr(element, factory, attribKey)
  if !attr:
    return none(int)

  try:
    return some(parseInt(&attr))
  except ValueError:
    return none(int)

func getUintAttr*(
    element: dom.Element, factory: dom.AtomFactory, attribKey: string
): Option[uint] =
  let attr = getAttr(element, factory, attribKey)
  if !attr:
    return none(uint)

  try:
    return some(parseUint(&attr))
  except ValueError:
    return none(uint)

func getElementById*(
    node: dom.Node, factory: dom.AtomFactory, id: string
): Option[dom.Element] =
  if node of dom.Element and
      (let value = getAttr(Element(node), factory, "id"); *value and &value == id):
    return some(Element(node))

  for child in node.childList:
    let res = getElementById(child, factory, id)
    if *res:
      return res

  none(Element)

func textContent*(node: dom.Node): string =
  # NOTE: I don't think this is compliant yet...
  var buffer: string # FIXME: Prealloc

  for child in node.childList:
    if child of dom.Text:
      buffer &= Text(child).data

    buffer &= child.textContent

  ensureMove(buffer)

func getElementsByTagName*(element: dom.Node, qualifiedName: string): seq[dom.Element] =
  var elems: seq[dom.Element] # TODO: Preallocate atleast a bit?
  if element of dom.Element and
      (qualifiedName == "*" or $tagType(Element(element)) == qualifiedName):
    elems &= Element(element)

  for child in element.childList:
    if not (child of dom.Element):
      continue

    let child = Element(child)
    if qualifiedName == "*" or $tagType(child) == qualifiedName:
      elems &= child

    elems &= getElementsByTagName(child, qualifiedName)

  ensureMove(elems)
