## Very incomplete bindings for `Element`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import
  components/js/runtime/vm/atom,
  components/js/runtime/atom_helpers,
  components/js/runtime/[arguments, bridge, construction, types],
  components/js/runtime/abstract/[coercible, to_number, to_string],
  components/dom/dom,
  components/html/dom_utils
import pkg/shakar, pretty, tables

type JSElement* = object
  internal*: Hidden[dom.Element]
  textContent*: FieldAccessor

proc toJSElement*(runtime: Runtime, element: dom.Element): JSElement =
  JSElement(
    internal: hidden(element),
    textContent: FieldAccessor(
      getter: proc(this: JSValue) =
        print this
        ret cast[dom.Element](&getInt(&this.tagged("internal"))).textContent
      ,
      setter: proc(this: JSValue, value: JSValue) =
        assert off, "textContent setter"
      ,
    ),
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
