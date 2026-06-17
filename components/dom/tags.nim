import std/options
import components/dom/dom
import components/scripting/types

type
  # HTML elements
  HTMLTemplateElement* = ref object of dom.Element
    content*: DocumentFragment

  HTMLImageElement* = ref object of dom.Element
    src*: Option[string]
    width*, height*: Option[uint]

  HTMLAnchorElement* = ref object of dom.Element
    href*: Option[string]

  HTMLScriptElement* = ref object of dom.Element
    script*: Script
