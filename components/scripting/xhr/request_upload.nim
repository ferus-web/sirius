## Implementation of `XMLHttpRequestEventTarget` and `XMLHttpRequestUpload`
## 
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import components/js/runtime/prelude
import components/scripting/dom/[event_target]
import pkg/[chronicles, shakar]

logScope:
  topics = "xhr/request_upload"

type
  XMLHttpRequestEventTarget* = object of event_target.EventTarget
  XMLHttpRequestUpload* = object of XMLHttpRequestEventTarget

proc onloadstartGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onloadstart getter"
  undefined(rt)

proc onloadstartSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onloadstart setter"

proc onprogressGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onprogress getter"
  undefined(rt)

proc onprogressSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onprogress setter"

proc onabortGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onabort getter"
  undefined(rt)

proc onabortSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onabort setter"

proc onerrorGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onerror getter"
  undefined(rt)

proc onerrorSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onerror setter"

proc onloadGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onload getter"
  undefined(rt)

proc onloadSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onload setter"

proc ontimeoutGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.ontimeout getter"
  undefined(rt)

proc ontimeoutSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.ontimeout setter"

proc onloadendGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onloadend getter"
  undefined(rt)

proc onloadendSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: XMLHttpRequestEventTarget.onloadend setter"

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("XMLHttpRequestEventTarget", XMLHttpRequestEventTarget)
  runtime.defineAccessor(
    XMLHttpRequestEventTarget,
    "onloadstart",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret onloadstartGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        onloadstartSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequestEventTarget,
    "onprogress",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret onprogressGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        onprogressSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequestEventTarget,
    "onabort",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret onabortGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        onabortSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequestEventTarget,
    "onerror",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret onerrorGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        onerrorSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequestEventTarget,
    "onload",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret onloadGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        onloadSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequestEventTarget,
    "ontimeout",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret ontimeoutGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        ontimeoutSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequestEventTarget,
    "onloadend",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret onloadendGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        onloadendSetter(rt = runtime, this, value),
    ),
  )

  runtime.registerType("XMLHttpRequestUpload", XMLHttpRequestUpload)
