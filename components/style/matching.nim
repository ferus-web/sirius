## Basic matching routines
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[tables]
import components/html/[dom, dom_utils], components/style/types
import pkg/[chronicles, shakar]

logScope:
  topics = "style/matching"

func matches*(element: Element, factory: MAtomFactory, selector: Selector): bool =
  case selector.kind
  of skType:
    # debugEcho "element.tagType: " & $element.tagType & "; selector.tag: " & selector.tag
    return $element.tagType == selector.tag
  of skUniversal:
    # TODO: We don't emit this selector in parsing yet
    return true
  of skId:
    let idAttr = element.getAttr(factory, "id")
    return *idAttr and selector.id == &idAttr
  of skClass:
    let classAttr = element.getAttr(factory, "class")
    return *classAttr and selector.class == &classAttr
  else:
    # TODO: Implement the rest, but it's fine for now.
    return false

func getSpecificity*(selector: Selector): uint =
  case selector.kind
  of skId:
    return 1000000
  of skClass, skAttr:
    return 1000
  of skType:
    return 1
  of skUniversal:
    return 0

proc resolveStyling*(
    root: Node, factory: MAtomFactory, stylesheet: Stylesheet
): StyleMap =
  debug "Resolve styling map", numRules = stylesheet.len
  var map: StyleMap

  proc visit(node: Node) =
    if node of Element:
      let elem = Element(node)
      var computed: ComputedStyle

      var specifsTracker: Table[string, uint]

      for rule in stylesheet:
        if elem.matches(factory, rule.selector):
          let
            ruleSpec = getSpecificity(rule.selector)
            currentSpec = specifsTracker.getOrDefault(rule.key, 0'u)

          if ruleSpec >= currentSpec:
            computed[rule.key] = rule.value
            specifsTracker[rule.key] = ruleSpec

      if computed.len > 0:
        map[node] = ensureMove(computed)

    for child in node.childList:
      visit(child)

  visit(root)
  map # FIXME: Can't move this directly, welp
