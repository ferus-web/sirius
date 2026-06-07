import std/options
import components/dom/dom

type
  # HTML elements
  HTMLTemplateElement* = ref object of dom.Element
    content*: DocumentFragment

  HTMLImageElement* = ref object of dom.Element
    src*: Option[string]

    width*, height*: Option[uint]

  HTMLAnchorElement* = ref object of dom.Element
    href*: Option[string]
