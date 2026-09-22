## Implementation of `WebSocket`
## https://websockets.spec.whatwg.org/#dom-websocket-websocket
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[hashes, tables, strformat]
import
  components/js/runtime/prelude,
  components/js/stdlib/types/std_string_type,
  components/js/stdlib/errors,
  components/scripting/dom/event_target,
  components/scripting/url,
  components/dom/dom,
  components/net/ws/types,
  components/html/messageevents,
  components/scripting/dom/event,
  components/scripting/html/message_event,
  components/scripting/websocket/close_event
import pkg/[chronicles, results, shakar, url]

logScope:
  topics = "websocket"

type
  # HACK: thanks, I hate it.
  WebSocket* = ref object of dom.EventTarget
    url*: URL
    protocols*: seq[string]

  WebSocketHostCallbacks* = object
    createWebSocket*: proc(
      url: URL,
      onopen: proc(client: WebSocket) {.gcsafe.},
      onrecv: proc(client: WebSocket, text: string) {.gcsafe.},
      onerror: proc(client: WebSocket, error: string) {.gcsafe.},
      onclose: proc(client: WebSocket, event: CloseEvent) {.gcsafe.},
    ): Result[WebSocket, string] {.gcsafe.}
    getReadyState*: proc(ws: WebSocket): WSClientState {.gcsafe.}
    send*: proc(ws: WebSocket, data: string) {.gcsafe.}
    getURLRecord*: proc(ws: WebSocket): URL {.gcsafe.}

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

proc urlGetter(rt: Runtime, this: JSValue, callbacks: WebSocketHostCallbacks): JSValue =
  ## https://websockets.spec.whatwg.org/#dom-websocket-url

  # The url getter steps are to return this’s url, serialized.
  rt.wrap($callbacks.getURLRecord(&this.getPrivateObject(WebSocket)))

proc readyStateGetter(
    rt: Runtime, this: JSValue, callbacks: WebSocketHostCallbacks
): JSValue =
  ## https://websockets.spec.whatwg.org/#websocket-ready-state

  # The readyState getter steps are to return this’s ready state.
  rt.wrap(cast[uint16](callbacks.getReadyState(&this.getPrivateObject(WebSocket))))
    # NOTE: Technically, WSClientState is a uint8 but it doesn't matter.

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
  let
    obj = rt.createObjFromType(JSWebSocket)
    wsTarget = callbacks.createWebSocket(
      (
        if rt.isA(url, JSString):
          &tryParseURL(rt.ToString(url)) # TODO: Implement this constructor properly :(
        else:
          rt.toNativeURL(url)
      ),
      onopen = proc(ws: WebSocket) {.gcsafe.} =
        discard dispatchEvent(ws, "open", undefined(rt)),
      onrecv = proc(ws: WebSocket, text: string) {.gcsafe.} =
        discard dispatchEvent(
          ws,
          "message",
          rt.wrapMessageEvent(
            newMessageEvent(data = text, origin = "", lastEventId = "")
          ),
        ), # TODO: Set origin properly
      onerror = proc(ws: WebSocket, error: string) {.gcsafe.} =
        let event = rt.createObjFromType(Event)
        event["type"] = rt.wrap("error")
        event["target"] = obj
        event["currentTarget"] = obj

        when not defined(release):
          event["siriusNetError"] = rt.wrap(error)
            # we might as well throw this in for funsies :P

        discard dispatchEvent(ws, "error", event),
      onclose = proc(ws: WebSocket, event: CloseEvent) {.gcsafe.} =
        discard dispatchEvent(ws, "close", rt.newCloseEvent(event)),
    )

  if !wsTarget:
    # TODO: Proper error type for this once that works
    rt.typeError(&"Cannot create WebSocket: {wsTarget.error()}")
    return

  obj.setHiddenField(URLField, rt.wrap(hidden(url)))
  obj.setHiddenField(ProtocolsField, rt.wrap(hidden(url)))
  obj.setHiddenField("internal", rt.wrap(hidden(&wsTarget)))

  obj

proc close(rt: Runtime, this: JSValue, code: uint16, reason: JSValue): JSValue =
  warn "IMPLEMENTME: WebSocket::close()", code = code, reason = rt.ToString(reason)
  undefined(rt)

proc send(
    rt: Runtime, this: JSValue, data: JSValue, callbacks: WebSocketHostCallbacks
): JSValue =
  ## https://websockets.spec.whatwg.org/#dom-websocket-send

  let node = &this.getPrivateObject(WebSocket)

  if not rt.isA(data, JSString):
    rt.typeError(&"Cannot send data via WebSocket: argument 1 must be a String")
      # TODO: Other types when I implement them (Blob/ArrayBuffer/ArrayBufferView)
    return

  # The send(data) method steps are:

  # 1. If this’s ready state is CONNECTING, then throw an "InvalidStateError" DOMException.
  if callbacks.getReadyState(node) == WSClientState.Connecting:
    # TODO: DOMException and InvalidStateError implementations!!!
    rt.typeError("WebSocket is still connecting to the endpoint")
    return

  # 2. Run the appropriate set of steps from the following list:

  # NOTE: I know this is redundant, I'm just keeping it here for later.
  if rt.isA(data, JSString):
    # If data is a string
    # If the WebSocket connection is established and the WebSocket closing handshake has not yet started, then the user agent must send a WebSocket Message comprised of the data argument using a text frame opcode; if the data cannot be sent, e.g. because it would need to be buffered but the buffer is full, the user agent must flag the WebSocket as full and then close the WebSocket connection. Any invocation of this method with a string argument that does not throw an exception must increase the bufferedAmount attribute by the number of bytes needed to express the argument as UTF-8. [UNICODE] [ENCODING] [WSP]

    # NOTE: all of this stuff is to be handled directly by net::ws::client
    callbacks.send(node, rt.ToString(data))

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
        ret urlGetter(rt = runtime, this = this, callbacks = callbacks)
    ),
  )
  runtime.defineAccessor(
    JSWebSocket,
    "readyState",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret readyStateGetter(rt = runtime, this = this, callbacks = callbacks)
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
      ret send(rt = runtime, this = this, data = data, callbacks = callbacks)
    ,
  )
