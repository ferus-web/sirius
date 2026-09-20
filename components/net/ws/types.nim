## WebSocket client types
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/net/curl_wrapper, components/impure/libcurl

type
  WSClientState* {.pure, size: sizeof(uint8).} = enum
    Connecting = 0
    Open = 1
    Closing = 2
    Closed = 3

  WSClientCallback* = proc(client: WebSocketClient) {.gcsafe.}
  WSClientErrorCallback* = proc(client: WebSocketClient, error: string) {.gcsafe.}
  WSClientTextFrameCallback* = proc(client: WebSocketClient, text: string) {.gcsafe.}

  WSClientCallbacks* = object
    opened*: WSClientCallback
    error*: WSClientErrorCallback
    closed*: WSClientCallback

    textFrame*: WSClientTextFrameCallback

  WebSocketClientObj = object
    handle*: Easy

    state*: WSClientState
    callbacks*: WSClientCallbacks

    curlErrorBuffer*: string

  WebSocketClient* = ref WebSocketClientObj
