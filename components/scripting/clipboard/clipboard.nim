import components/js/runtime/prelude, components/scripting/dom/event_target
import pkg/[chronicles, shakar]

logScope:
  topics = "clipboard"

type Clipboard* = object of event_target.EventTarget

proc read(rt: Runtime, this: JSValue, formats: JSValue): JSValue =
  warn "IMPLEMENTME: Clipboard::read()", formats = rt.ToString(formats)
  undefined(rt)

proc readText(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Clipboard::readText()"
  undefined(rt)

proc write(rt: Runtime, this: JSValue, data: JSValue): JSValue =
  warn "IMPLEMENTME: Clipboard::write()", data = rt.ToString(data)
  undefined(rt)

proc writeText(rt: Runtime, this: JSValue, data: JSValue): JSValue =
  warn "IMPLEMENTME: Clipboard::writeText()", data = rt.ToString(data)
  undefined(rt)

proc generateGlobal*(rt: Runtime, navigator: JSValue) =
  navigator["clipboard"] = rt.createObjFromType(Clipboard)

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("Clipboard", Clipboard)

  runtime.definePrototypeFn(
    Clipboard,
    "read",
    proc(this: JSValue) =
      let formats = &runtime.argument(1, required = false)
      ret read(rt = runtime, this = this, formats = formats)
    ,
  )

  runtime.definePrototypeFn(
    Clipboard,
    "readText",
    proc(this: JSValue) =
      ret readText(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    Clipboard,
    "write",
    proc(this: JSValue) =
      let data = &runtime.argument(1, required = true)
      ret write(rt = runtime, this = this, data = data)
    ,
  )

  runtime.definePrototypeFn(
    Clipboard,
    "writeText",
    proc(this: JSValue) =
      let data = &runtime.argument(1, required = true)
      ret writeText(rt = runtime, this = this, data = data)
    ,
  )
