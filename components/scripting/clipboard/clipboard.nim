## `Clipboard` implementation
## https://www.w3.org/TR/clipboard-apis/
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import
  components/js/runtime/prelude,
  components/scripting/dom/event_target,
  components/js/stdlib/prelude
import pkg/[chronicles, shakar]

logScope:
  topics = "clipboard"

type
  ClipboardHostCallbacks* = object
    writeText*: proc(promise: JSValue, rt: Runtime, text: string) {.gcsafe.}

  Clipboard* = object of event_target.EventTarget

proc read(rt: Runtime, this: JSValue, formats: JSValue): JSValue =
  warn "IMPLEMENTME: Clipboard::read()", formats = rt.ToString(formats)
  undefined(rt)

proc readText(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Clipboard::readText()"
  undefined(rt)

proc write(rt: Runtime, this: JSValue, data: JSValue): JSValue =
  warn "IMPLEMENTME: Clipboard::write()", data = rt.ToString(data)
  undefined(rt)

proc writeText(
    rt: Runtime, this: JSValue, data: JSValue, callbacks: ClipboardHostCallbacks
): JSValue =
  ## 7.3.4. writeText(data)
  ## https://www.w3.org/TR/clipboard-apis/#dom-clipboard-writetext

  # 1. Let realm be this’s relevant realm.
  # 2. Let p be a new promise in realm.
  let p = newPromise(rt)
  let promiseObj = toJSPromise(rt, p.promise)

  # 3. Run the following steps in parallel:
  callbacks.writeText(promiseObj, rt, rt.ToString(data))

  # 4. Return p.
  promiseObj

proc generateGlobal*(rt: Runtime, navigator: JSValue) =
  navigator["clipboard"] = rt.createObjFromType(Clipboard)

proc generateBindings*(runtime: Runtime, callbacks: ClipboardHostCallbacks) =
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
      ret writeText(rt = runtime, this = this, data = data, callbacks = callbacks)
    ,
  )
