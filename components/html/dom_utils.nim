## Utility routines mostly related to DOM traversal
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[hashes, options, strutils]
import components/html/dom
import pkg/shakar

func hash*(node: dom.Node): hashes.Hash {.inline.} =
  hash(cast[pointer](node))

func getAttr*(
    element: dom.Element, factory: dom.MAtomFactory, attribKey: string
): Option[string] {.inline.} =
  for attr in element.attrs:
    if atomToStr(factory, attr.name) == attribKey:
      return some(attr.value)

  none(string)

func getIntAttr*(
    element: dom.Element, factory: dom.MAtomFactory, attribKey: string
): Option[int] =
  let attr = getAttr(element, factory, attribKey)
  if !attr:
    return none(int)

  try:
    return some(parseInt(&attr))
  except ValueError:
    return none(int)

func getUintAttr*(
    element: dom.Element, factory: dom.MAtomFactory, attribKey: string
): Option[uint] =
  let attr = getAttr(element, factory, attribKey)
  if !attr:
    return none(uint)

  try:
    return some(parseUint(&attr))
  except ValueError:
    return none(uint)
