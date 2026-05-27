## Utility routines mostly related to DOM traversal
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[hashes, options]
import components/html/dom

func hash*(node: dom.Node): hashes.Hash {.inline.} =
  hash(cast[pointer](node))

func getAttr*(
    element: dom.Element, factory: dom.MAtomFactory, attribKey: string
): Option[string] {.inline.} =
  for attr in element.attrs:
    if atomToStr(factory, attr.name) == attribKey:
      return some(attr.value)

  none(string)
