import std/options
import components/dom/dom, components/html/[form, meta]
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

  HTMLInputElement* = ref object of dom.Element
    kind*: Option[InputKind]
    value*: Option[string]

    inputBuffer*: string

  HTMLMetaElement* = ref object of dom.Element
    httpEquiv*: Option[HTTPEquiv]
    name*: Option[MetadataName]
    content*, media*: Option[string]
