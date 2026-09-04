import components/js/runtime/prelude
import pkg/[chronicles, shakar]

logScope:
  topics = "stub" # TODO: Replace this with something more appropriate!

type EventTarget* = object
proc newEventTarget*(rt: Runtime): EventTarget =
  EventTarget()

proc addEventListener(
    rt: Runtime, this: JSValue, typ: JSValue, callback: JSValue, options: JSValue
): JSValue =
  warn "IMPLEMENTME: EventTarget::addEventListener()",
    typ = rt.ToString(typ),
    callback = rt.ToString(callback),
    options = rt.ToString(options)
  undefined(rt)

proc removeEventListener(
    rt: Runtime, this: JSValue, typ: JSValue, callback: JSValue, options: JSValue
): JSValue =
  warn "IMPLEMENTME: EventTarget::removeEventListener()",
    typ = rt.ToString(typ),
    callback = rt.ToString(callback),
    options = rt.ToString(options)
  undefined(rt)

proc dispatchEvent(rt: Runtime, this: JSValue, event: JSValue): JSValue =
  warn "IMPLEMENTME: EventTarget::dispatchEvent()", event = rt.ToString(event)
  undefined(rt)

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("EventTarget", EventTarget)

  runtime.definePrototypeFn(
    EventTarget,
    "addEventListener",
    proc(this: JSValue) =
      let typ = &runtime.argument(1, required = true)
      let callback = &runtime.argument(2, required = true)
      let options = &runtime.argument(3, required = false)
      ret addEventListener(
        rt = runtime, this = this, typ = typ, callback = callback, options = options
      )
    ,
  )

  runtime.definePrototypeFn(
    EventTarget,
    "removeEventListener",
    proc(this: JSValue) =
      let typ = &runtime.argument(1, required = true)
      let callback = &runtime.argument(2, required = true)
      let options = &runtime.argument(3, required = false)
      ret removeEventListener(
        rt = runtime, this = this, typ = typ, callback = callback, options = options
      )
    ,
  )

  runtime.definePrototypeFn(
    EventTarget,
    "dispatchEvent",
    proc(this: JSValue) =
      let event = &runtime.argument(1, required = true)
      ret dispatchEvent(rt = runtime, this = this, event = event)
    ,
  )
