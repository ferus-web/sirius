import std/options
import components/dom/dom

type
  # HTML elements
  HTMLTemplateElement* = ref object of Element
    content*: DocumentFragment

  HTMLImageElement* = ref object of Element
    src*: Option[string]

    width*, height*: Option[uint]
