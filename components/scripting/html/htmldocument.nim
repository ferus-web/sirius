## `Document` implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import
  components/js/runtime/prelude, components/dom/dom, components/scripting/dom/[document]
import pkg/[chronicles, shakar]

logScope:
  topics = "html/document"

const InternalField = "internal"

proc locationGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.location getter"
  undefined(rt)

proc domainGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.domain getter"
  undefined(rt)

proc domainSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Document.domain setter"

proc referrerGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.referrer getter"
  undefined(rt)

proc cookieGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.cookie getter"
  undefined(rt)

proc cookieSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Document.cookie setter"

proc lastModifiedGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.lastModified getter"
  undefined(rt)

proc readyStateGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.readyState getter"
  undefined(rt)

proc titleGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.title getter"
  undefined(rt)

proc titleSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Document.title setter"

proc dirGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.dir getter"
  undefined(rt)

proc dirSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Document.dir setter"

proc bodyGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.body getter"
  undefined(rt)

proc bodySetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Document.body setter"

proc headGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.head getter"
  undefined(rt)

proc imagesGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.images getter"
  undefined(rt)

proc embedsGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.embeds getter"
  undefined(rt)

proc pluginsGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.plugins getter"
  undefined(rt)

proc linksGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.links getter"
  undefined(rt)

proc formsGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.forms getter"
  undefined(rt)

proc scriptsGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.scripts getter"
  undefined(rt)

proc currentScriptGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.currentScript getter"
  undefined(rt)

proc defaultViewGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.defaultView getter"
  undefined(rt)

proc designModeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.designMode getter"
  undefined(rt)

proc designModeSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Document.designMode setter"

proc hiddenGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.hidden getter"
  undefined(rt)

proc visibilityStateGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.visibilityState getter"
  undefined(rt)

proc onreadystatechangeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.onreadystatechange getter"
  undefined(rt)

proc onreadystatechangeSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Document.onreadystatechange setter"

proc onvisibilitychangeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document.onvisibilitychange getter"
  undefined(rt)

proc onvisibilitychangeSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Document.onvisibilitychange setter"

proc getElementsByName(rt: Runtime, this: JSValue, elementName: JSValue): JSValue =
  warn "IMPLEMENTME: Document::getElementsByName()",
    elementName = rt.ToString(elementName)
  undefined(rt)

proc open(rt: Runtime, this: JSValue, unused1: JSValue, unused2: JSValue): JSValue =
  warn "IMPLEMENTME: Document::open()",
    unused1 = rt.ToString(unused1), unused2 = rt.ToString(unused2)
  undefined(rt)

proc open(
    rt: Runtime, this: JSValue, url: JSValue, name: JSValue, features: JSValue
): JSValue =
  warn "IMPLEMENTME: Document::open()",
    url = rt.ToString(url), name = rt.ToString(name), features = rt.ToString(features)
  undefined(rt)

proc close(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document::close()"
  undefined(rt)

proc write(rt: Runtime, this: JSValue, text: JSValue): JSValue =
  warn "IMPLEMENTME: Document::write()", text = rt.ToString(text)
  undefined(rt)

proc writeln(rt: Runtime, this: JSValue, text: JSValue): JSValue =
  warn "IMPLEMENTME: Document::writeln()", text = rt.ToString(text)
  undefined(rt)

proc hasFocus(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Document::hasFocus()"
  undefined(rt)

proc execCommand(
    rt: Runtime, this: JSValue, commandId: JSValue, showUI: bool, value: JSValue
): JSValue =
  warn "IMPLEMENTME: Document::execCommand()",
    commandId = rt.ToString(commandId), showUI = showUI, value = rt.ToString(value)
  undefined(rt)

proc queryCommandEnabled(rt: Runtime, this: JSValue, commandId: JSValue): JSValue =
  warn "IMPLEMENTME: Document::queryCommandEnabled()",
    commandId = rt.ToString(commandId)
  undefined(rt)

proc queryCommandIndeterm(rt: Runtime, this: JSValue, commandId: JSValue): JSValue =
  warn "IMPLEMENTME: Document::queryCommandIndeterm()",
    commandId = rt.ToString(commandId)
  undefined(rt)

proc queryCommandState(rt: Runtime, this: JSValue, commandId: JSValue): JSValue =
  warn "IMPLEMENTME: Document::queryCommandState()", commandId = rt.ToString(commandId)
  undefined(rt)

proc queryCommandSupported(rt: Runtime, this: JSValue, commandId: JSValue): JSValue =
  warn "IMPLEMENTME: Document::queryCommandSupported()",
    commandId = rt.ToString(commandId)
  undefined(rt)

proc queryCommandValue(rt: Runtime, this: JSValue, commandId: JSValue): JSValue =
  warn "IMPLEMENTME: Document::queryCommandValue()", commandId = rt.ToString(commandId)
  undefined(rt)

proc generateBindings*(runtime: Runtime) =
  runtime.defineAccessor(
    Document,
    "location",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret locationGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "domain",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret domainGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        domainSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Document,
    "referrer",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret referrerGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "cookie",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret cookieGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        cookieSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Document,
    "lastModified",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret lastModifiedGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "readyState",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret readyStateGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "title",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret titleGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        titleSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Document,
    "dir",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret dirGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        dirSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Document,
    "body",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret bodyGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        bodySetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Document,
    "head",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret headGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "images",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret imagesGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "embeds",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret embedsGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "plugins",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret pluginsGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "links",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret linksGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "forms",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret formsGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "scripts",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret scriptsGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "currentScript",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret currentScriptGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "defaultView",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret defaultViewGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "designMode",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret designModeGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        designModeSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Document,
    "hidden",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret hiddenGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "visibilityState",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret visibilityStateGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Document,
    "onreadystatechange",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret onreadystatechangeGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        onreadystatechangeSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Document,
    "onvisibilitychange",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret onvisibilitychangeGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        onvisibilitychangeSetter(rt = runtime, this, value),
    ),
  )

  runtime.definePrototypeFn(
    document.Document,
    "getElementsByName",
    proc(this: JSValue) =
      let elementName = &runtime.argument(1, required = true)
      ret getElementsByName(rt = runtime, this = this, elementName = elementName)
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "open",
    proc(this: JSValue) =
      let unused1 = &runtime.argument(1, required = false)
      let unused2 = &runtime.argument(2, required = false)
      ret open(rt = runtime, this = this, unused1 = unused1, unused2 = unused2)
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "open",
    proc(this: JSValue) =
      let url = &runtime.argument(1, required = true)
      let name = &runtime.argument(2, required = true)
      let features = &runtime.argument(3, required = true)
      ret open(rt = runtime, this = this, url = url, name = name, features = features)
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "close",
    proc(this: JSValue) =
      ret close(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "write",
    proc(this: JSValue) =
      let text = &runtime.argument(1, required = true)
      ret write(rt = runtime, this = this, text = text)
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "writeln",
    proc(this: JSValue) =
      let text = &runtime.argument(1, required = true)
      ret writeln(rt = runtime, this = this, text = text)
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "hasFocus",
    proc(this: JSValue) =
      ret hasFocus(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "execCommand",
    proc(this: JSValue) =
      let commandId = &runtime.argument(1, required = true)
      let showUI = &getBool(&runtime.argument(2, required = false))
      let value = &runtime.argument(3, required = false)
      ret execCommand(
        rt = runtime, this = this, commandId = commandId, showUI = showUI, value = value
      )
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "queryCommandEnabled",
    proc(this: JSValue) =
      let commandId = &runtime.argument(1, required = true)
      ret queryCommandEnabled(rt = runtime, this = this, commandId = commandId)
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "queryCommandIndeterm",
    proc(this: JSValue) =
      let commandId = &runtime.argument(1, required = true)
      ret queryCommandIndeterm(rt = runtime, this = this, commandId = commandId)
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "queryCommandState",
    proc(this: JSValue) =
      let commandId = &runtime.argument(1, required = true)
      ret queryCommandState(rt = runtime, this = this, commandId = commandId)
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "queryCommandSupported",
    proc(this: JSValue) =
      let commandId = &runtime.argument(1, required = true)
      ret queryCommandSupported(rt = runtime, this = this, commandId = commandId)
    ,
  )

  runtime.definePrototypeFn(
    document.Document,
    "queryCommandValue",
    proc(this: JSValue) =
      let commandId = &runtime.argument(1, required = true)
      ret queryCommandValue(rt = runtime, this = this, commandId = commandId)
    ,
  )
