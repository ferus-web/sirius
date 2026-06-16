## Basic matching routines
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, sequtils, strutils, sugar, tables]
import components/dom/dom, components/html/dom_utils, components/style/types
import pkg/[chronicles, shakar]

logScope:
  topics = "style/matching"

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

func getSpecificity*(selector: CompoundSelector): uint =
  var total: uint
  for sel in selector:
    total += getSpecificity(sel)

  move(total)

func getSpecificity*(complex: ComplexSelector): uint =
  var total: uint = 0
  for item in complex:
    total += getSpecificity(item.selector)
  return total

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
    return
      *classAttr and any(split(&classAttr), (class: string) => class == selector.class)
        # TODO: There's probably a cleaner way, right?
  else:
    # TODO: Implement the rest, but it's fine for now.
    return false

func matches*(
    element: dom.Element, factory: dom.MAtomFactory, selector: CompoundSelector
): bool =
  for sel in selector:
    if not matches(element, factory, sel):
      return false

  true

func matches*(
    element: dom.Element, factory: dom.MAtomFactory, complex: ComplexSelector
): bool =
  if complex.len == 0:
    return false

  func checkPath(elem: dom.Element, stepIdx: int): bool =
    if not matches(elem, factory, complex[stepIdx].selector):
      return false

    if stepIdx == 0:
      return true

    let combinator = complex[stepIdx - 1].combinator
    let nextIdx = stepIdx - 1

    case combinator
    of Combinator.Descendant:
      var ancestor = elem.parentNode
      while ancestor != nil:
        if ancestor of dom.Element and checkPath(dom.Element(ancestor), nextIdx):
          return true
        ancestor = ancestor.parentNode
      return false
    of Combinator.Child:
      let parentNode = elem.parentNode
      if parentNode != nil and parentNode of dom.Element:
        return checkPath(dom.Element(parentNode), nextIdx)
      return false
    of Combinator.Adjacent, Combinator.Sibling:
      # TODO: Implement this!!!
      return false

  return checkPath(element, complex.len - 1)

func matches*(
    element: dom.Element, factory: dom.MAtomFactory, list: SelectorList
): bool =
  for complex in list:
    if matches(element, factory, complex):
      return true
  return false

proc resolveStyling*(
    root: dom.Node, factory: dom.MAtomFactory, stylesheet: Stylesheet
): StyleMap =
  debug "Resolve styling map", numRules = stylesheet.len
  var map: StyleMap

  proc visit(node: dom.Node) =
    if node of dom.Element:
      let elem = dom.Element(node)
      var computed: ComputedStyle
      var specifsTracker = newTable[string, uint]()

      for rule in stylesheet:
        for complexSel in rule.selectors:
          if matches(elem, factory, complexSel):
            let ruleSpec = getSpecificity(complexSel)

            for decl in rule.declarations:
              let lowerKey = toLowerAscii(decl.key)
              let currentSpec = specifsTracker.getOrDefault(lowerKey, 0'u)

              if ruleSpec >= currentSpec:
                computed[lowerKey] = decl.value
                specifsTracker[lowerKey] = ruleSpec

      if computed.len > 0:
        map[node] = ensureMove(computed)

    for child in node.childList:
      visit(child)

  visit(root)
  move(map)
