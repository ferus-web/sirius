## `HTMLHeadElement` JS bindings
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import components/js/runtime/prelude
import components/scripting/dom/element
import components/dom/[dom, tags]
import pkg/[chronicles, shakar]

logScope:
  topics = "html/element/head"

type HTMLHeadElement* = object of element.Element

proc toJSHTMLHeadElement*(rt: Runtime, element: tags.HTMLHeadElement): JSValue =
  let elem = rt.createObjFromType(head.HTMLHeadElement)
  elem.setHiddenField("internal", rt.wrap(hidden(element)))

  elem

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("HTMLHeadElement", head.HTMLHeadElement)
