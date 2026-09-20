## `JSCloseEvent` implementation
## https://websockets.spec.whatwg.org/#the-closeevent-interface
## 
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import components/js/runtime/prelude, components/scripting/dom/event, components/dom/dom
import pkg/[chronicles, shakar]

logScope:
  topics = "close_event"

type
  CloseEvent* = ref object of dom.EventTarget
    # TODO: This should inherit dom.Event when that works
    wasClean*: bool
    code*: uint16
    reason*: string

  JSCloseEvent* = object of event.Event

proc wasCleanGetter(rt: Runtime, this: JSValue): JSValue =
  rt.wrap((&this.getPrivateObject(CloseEvent)).wasClean)

proc codeGetter(rt: Runtime, this: JSValue): JSValue =
  rt.wrap((&this.getPrivateObject(CloseEvent)).code)

proc reasonGetter(rt: Runtime, this: JSValue): JSValue =
  rt.wrap((&this.getPrivateObject(CloseEvent)).reason)

proc newCloseEvent*(rt: Runtime, event: CloseEvent): JSValue =
  let eventObj = rt.createObjFromType(JSCloseEvent)
  eventObj.setHiddenField("internal", rt.wrap(hidden(event)))

  eventObj

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("CloseEvent", JSCloseEvent)
  runtime.defineAccessor(
    JSCloseEvent,
    "wasClean",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret wasCleanGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    JSCloseEvent,
    "code",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret codeGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    JSCloseEvent,
    "reason",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret reasonGetter(rt = runtime, this = this)
    ),
  )
