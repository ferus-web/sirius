## Basic matching routines
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, tables]
import components/html/[dom, dom_utils], components/style/types
import pkg/[chronicles, shakar]
import pretty

logScope:
  topics = "style/matching"

func matches*(
    element: dom.Element, factory: dom.MAtomFactory, selector: Selector
): bool =
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

func matches*(
    element: dom.Element, factory: dom.MAtomFactory, selectors: seq[Selector]
): Option[int] =
  for i, selector in selectors:
    if matches(element, factory, selector):
      return some(i)

  none(int)

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
    root: dom.Node, factory: dom.MAtomFactory, stylesheet: Stylesheet
): StyleMap =
  debug "Resolve styling map", numRules = stylesheet.len
  var map: StyleMap
  print stylesheet

  proc visit(node: dom.Node) =
    if node of dom.Element:
      let elem = Element(node)
      var computed: ComputedStyle

      var specifsTracker: Table[string, uint]

      for rule in stylesheet:
        let winner = elem.matches(factory, rule.selectors)
        if *winner:
          # If there's a match:
          let
            ruleSpec = getSpecificity(rule.selectors[&winner])
            currentSpec = specifsTracker.getOrDefault(rule.key, 0'u)

          if ruleSpec >= currentSpec:
            # echo $rule.selectors[&winner] & ": " & rule.key & ": " & $rule.value
            computed[rule.key] = rule.value
            specifsTracker[rule.key] = ruleSpec

      if computed.len > 0:
        map[node] = ensureMove(computed)

    for child in node.childList:
      visit(child)

  visit(root)
  move(map)
