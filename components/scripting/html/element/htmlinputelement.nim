## `HTMLInputElement` JS bindings
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[strutils]
import components/js/runtime/prelude
import components/scripting/dom/element
import components/dom/[dom, tags]
import pkg/shakar

type JSHTMLInputElement* {.final.} = object of JSElement # value*: FieldAccessor

proc toJSHTMLInputElement*(runtime: Runtime, element: tags.HTMLInputElement): JSValue =
  let elem = runtime.createObjFromType(JSHTMLInputElement)
  elem.setHiddenField("internal", runtime.wrap(hidden(dom.Node(element))))

  elem

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("HTMLInputElement", JSHTMLInputElement)
