## Very incomplete bindings for `Element`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/strutils
import
  components/js/runtime/vm/atom,
  components/js/runtime/atom_helpers,
  components/js/runtime/[arguments, bridge, construction, types],
  components/js/runtime/abstract/[coercible, to_number, to_string],
  components/dom/dom,
  components/html/dom_utils
import pkg/shakar

type JSElement* = object
  internal*: Hidden[dom.Element]
  textContent*, parentElement*: FieldAccessor

  localName*, tagName*: string

proc toJSElement*(runtime: Runtime, element: dom.Element): JSElement =
  JSElement(
    internal: hidden(element),
    textContent: FieldAccessor(
      getter: proc(this: JSValue) =
        ret cast[dom.Element](&getInt(&this.tagged("internal"))).textContent
      ,
      setter: proc(this: JSValue, value: JSValue) =
        let element = cast[dom.Element](&getInt(&this.tagged("internal")))
        element.childList.setLen(1)

        let textData = runtime.ToString(value)
        if textData.len > 0:
          element.childList[0] = Text(data: textData, parentNode: element)

        element.document.edited = true,
    ),
    localName: element.document.factory.atomToStr(element.localName),
    tagName: toUpperAscii(element.document.factory.atomToStr(element.localName)),
  )

proc generateBindings*(runtime: Runtime) =
  runtime.registerType(prototype = JSElement, name = "Element")
  runtime.definePrototypeFn(
    JSElement,
    "toString",
    proc(this: JSValue) =
      ret "[object Element]"
    ,
  )
