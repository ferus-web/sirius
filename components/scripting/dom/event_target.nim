import components/js/runtime/prelude
import pkg/[chronicles, shakar]

logScope:
  topics = "stub" # TODO: Replace this with something more appropriate!

type EventTarget* = object

proc addEventListener(rt: Runtime, this: JSValue, type: string, callback: JSValue, options: JSValue): JSValue =
  warn "IMPLEMENTME: EventTarget::addEventListener()", type = type, callback = rt.ToString(callback), options = rt.ToString(options)
  undefined(rt)

proc removeEventListener(rt: Runtime, this: JSValue, type: string, callback: JSValue, options: JSValue): JSValue =
  warn "IMPLEMENTME: EventTarget::removeEventListener()", type = type, callback = rt.ToString(callback), options = rt.ToString(options)
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
      let type = runtime.ToString(&runtime.argument(1, required = true))
      let callback = &runtime.argument(2, required = true)
      let options = &runtime.argument(3, required = false)
      ret addEventListener(rt = runtime, this = this, type = type, callback = callback, options = options)
  )

  runtime.definePrototypeFn(
    EventTarget,
    "removeEventListener",
    proc(this: JSValue) =
      let type = runtime.ToString(&runtime.argument(1, required = true))
      let callback = &runtime.argument(2, required = true)
      let options = &runtime.argument(3, required = false)
      ret removeEventListener(rt = runtime, this = this, type = type, callback = callback, options = options)
  )

  runtime.definePrototypeFn(
    EventTarget,
    "dispatchEvent",
    proc(this: JSValue) =
      let event = &runtime.argument(1, required = true)
      ret dispatchEvent(rt = runtime, this = this, event = event)
  )

