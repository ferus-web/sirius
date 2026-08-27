## `HTMLInputElement` JS bindings
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[strutils]
import components/js/runtime/prelude
import components/scripting/dom/element
import components/dom/[dom, tags]
import pkg/shakar

type JSHTMLInputElement* {.final.} = object of JSElement
  value*: FieldAccessor

proc toJSHTMLInputElement*(runtime: Runtime, element: dom.Element): JSHTMLInputElement =
  JSHTMLInputElement(
    internal: hidden(element),
    textContent: getElementTextContentAccessor(runtime),
    innerHTML: getInnerHTMLTextContentAccessor(runtime),
    parentElement: (
      if element.parentNode != nil and element.parentNode of dom.Element:
        runtime.wrap(toJSElement(runtime, Element(element.parentNode)))
      else:
        null(runtime)
    ),
    localName: element.document.factory.atomToStr(element.localName),
    tagName: toUpperAscii(element.document.factory.atomToStr(element.localName)),
    onclick: getOnClickFieldAccessor(runtime),
    onkeydown: getOnKeyDownFieldAccessor(runtime),
    value: FieldAccessor(
      getter: proc(this: JSValue) =
        ret (&this.getPrivateObject(HTMLInputElement)).inputBuffer
      ,
      setter: proc(this: JSValue, value: JSValue) =
        let element = &this.getPrivateObject(HTMLInputElement)
        element.inputBuffer = runtime.ToString(value)
        element.document.edited = true,
    ),
  )

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("HTMLInputElement", JSHTMLInputElement)
