## Implementation of `JSWebSocket`
## https://websockets.spec.whatwg.org/#dom-websocket-websocket
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[hashes, tables]
import
  components/js/runtime/prelude,
  components/js/stdlib/types/std_string_type,
  components/scripting/dom/event_target,
  components/scripting/url,
  components/dom/dom
import pkg/[chronicles, shakar, url]

logScope:
  topics = "websocket"

type
  # HACK: thanks, I hate it.
  WebSocket* = ref object of dom.EventTarget
    url*: URL
    protocols*: seq[string]

  WebSocketHostCallbacks* = object
    createWebSocket*: proc(url: URL): WebSocket {.gcsafe.}

  JSWebSocket* = object of event_target.EventTarget

func hash*(ws: WebSocket): Hash =
  var value: Hash

  value = value !& hash(ws.url)
  value = value !& hash(ws.protocols)
  value = value !& hash(cast[uint64](ws)) # why not

const
  Connecting*: uint16 = 0
  Open*: uint16 = 1
  Closing*: uint16 = 2
  Closed*: uint16 = 3

  URLField = "url"
  ProtocolsField = "protocols"

proc urlGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket.url getter"
  undefined(rt)

proc readyStateGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket.readyState getter"
  undefined(rt)

proc bufferedAmountGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket.bufferedAmount getter"
  undefined(rt)

proc onopenGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket.onopen getter"
  undefined(rt)

proc onopenSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: JSWebSocket.onopen setter"

proc onerrorGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket.onerror getter"
  undefined(rt)

proc onerrorSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: JSWebSocket.onerror setter"

proc oncloseGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket.onclose getter"
  undefined(rt)

proc oncloseSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: JSWebSocket.onclose setter"

proc extensionsGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket.extensions getter"
  undefined(rt)

proc protocolGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket.protocol getter"
  undefined(rt)

proc onmessageGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket.onmessage getter"
  undefined(rt)

proc onmessageSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: JSWebSocket.onmessage setter"

proc binaryTypeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket.binaryType getter"
  undefined(rt)

proc binaryTypeSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: JSWebSocket.binaryType setter"

proc newJSWebSocket*(
    rt: Runtime, callbacks: WebSocketHostCallbacks, url: JSValue, protocols: JSValue
): JSValue =
  let obj = rt.createObjFromType(JSWebSocket)
  obj.setHiddenField(URLField, rt.wrap(hidden(url)))
  obj.setHiddenField(ProtocolsField, rt.wrap(hidden(url)))
  obj.setHiddenField(
    "internal",
    rt.wrap(
      hidden(
        callbacks.createWebSocket(
          (
            if rt.isA(url, JSString):
              &tryParseURL(rt.ToString(url))
                # TODO: Implement this constructor properly :(
            else:
              rt.toNativeURL(url)
          )
        )
      )
    ),
  )

  obj

proc close(rt: Runtime, this: JSValue, code: uint16, reason: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket::close()", code = code, reason = rt.ToString(reason)
  undefined(rt)

proc send(rt: Runtime, this: JSValue, data: JSValue): JSValue =
  warn "IMPLEMENTME: JSWebSocket::send()", data = rt.ToString(data)
  undefined(rt)

proc generateBindings*(runtime: Runtime, callbacks: WebSocketHostCallbacks) =
  runtime.registerType("WebSocket", JSWebSocket)
  runtime.setProperty(JSWebSocket, "CONNECTING", Connecting)
  runtime.setProperty(JSWebSocket, "OPEN", Open)
  runtime.setProperty(JSWebSocket, "CLOSING", Closing)
  runtime.setProperty(JSWebSocket, "CLOSED", Closed)
  runtime.defineConstructor(
    "WebSocket",
    proc() =
      ret newJSWebSocket(runtime, callbacks, &runtime.argument(1), &runtime.argument(2))
    ,
  )

  runtime.defineAccessor(
    JSWebSocket,
    "url",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret urlGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    JSWebSocket,
    "readyState",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret readyStateGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    JSWebSocket,
    "bufferedAmount",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret bufferedAmountGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    JSWebSocket,
    "onopen",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret onopenGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        onopenSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    JSWebSocket,
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
    JSWebSocket,
    "onclose",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret oncloseGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        oncloseSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    JSWebSocket,
    "extensions",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret extensionsGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    JSWebSocket,
    "protocol",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret protocolGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    JSWebSocket,
    "onmessage",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret onmessageGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        onmessageSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    JSWebSocket,
    "binaryType",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret binaryTypeGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        binaryTypeSetter(rt = runtime, this, value),
    ),
  )

  runtime.definePrototypeFn(
    JSWebSocket,
    "close",
    proc(this: JSValue) =
      let code =
        uint16(&getFloat(runtime.ToNumeric(&runtime.argument(1, required = false))))
      let reason = &runtime.argument(2, required = false)
      ret close(rt = runtime, this = this, code = code, reason = reason)
    ,
  )

  runtime.definePrototypeFn(
    JSWebSocket,
    "send",
    proc(this: JSValue) =
      let data = &runtime.argument(1, required = true)
      ret send(rt = runtime, this = this, data = data)
    ,
  )
