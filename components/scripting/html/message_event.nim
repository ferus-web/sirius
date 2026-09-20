## Implementation of `MessageEvent`
## https://html.spec.whatwg.org/multipage/comms.html#the-messageevent-interface
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import
  components/js/runtime/prelude,
  components/scripting/dom/event,
  components/html/messageevents
import pkg/[chronicles, shakar]

logScope:
  topics = "message_event"

type JSMessageEvent* = object of event.Event

proc dataGetter(rt: Runtime, this: JSValue): JSValue =
  let internal = this.getPrivateObject(MessageEvent)
  assert(*internal)

  rt.wrap((&internal).data)

proc originGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: MessageEvent.origin getter"
  undefined(rt)

proc lastEventIdGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: MessageEvent.lastEventId getter"
  undefined(rt)

proc sourceGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: MessageEvent.source getter"
  undefined(rt)

proc portsGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: MessageEvent.ports getter"
  undefined(rt)

proc newMessageEvent*(rt: Runtime, typ: JSValue, eventInitDict: JSValue): MessageEvent =
  MessageEvent()

proc wrapMessageEvent*(rt: Runtime, messageEvent: MessageEvent): JSValue =
  let obj = rt.createObjFromType(JSMessageEvent)
  obj.setHiddenField("internal", rt.wrap(hidden(messageEvent)))

  obj

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("MessageEvent", JSMessageEvent)
  runtime.defineAccessor(
    JSMessageEvent,
    "data",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret dataGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    JSMessageEvent,
    "origin",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret originGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    JSMessageEvent,
    "lastEventId",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret lastEventIdGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    JSMessageEvent,
    "source",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret sourceGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    JSMessageEvent,
    "ports",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret portsGetter(rt = runtime, this = this)
    ),
  )
