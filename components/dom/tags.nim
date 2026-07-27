import std/options
import components/dom/dom, components/html/[meta], components/html/form/types
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
    form*: Option[HTMLFormElement]
    name*: Option[string]

    inputBuffer*: string

  HTMLMetaElement* = ref object of dom.Element
    httpEquiv*: Option[HTTPEquiv]
    name*: Option[MetadataName]
    content*, media*: Option[string]

  HTMLFormElement* = ref object of dom.Element
    meth*: Option[FormMethod]
    action*: Option[string]
