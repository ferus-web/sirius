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

  WSClientCallback* = proc(client: WebSocketClient)
  WSClientErrorCallback* = proc(client: WebSocketClient, error: string)

  WSClientCallbacks* = object
    opened*: WSClientCallback
    error*: WSClientErrorCallback
    closed*: WSClientCallback

  WebSocketClientObj = object
    handle*: libcurl.CURL

    state*: WSClientState
    callbacks*: WSClientCallbacks

  WebSocketClient* = ref WebSocketClientObj

proc enterState*(client: WebSocketClient, state: WSClientState) =
  if client.state == state:
    return # We don't want to trigger any changes if the state already matches

  client.state = state
  case state
  of WSClientState.Connecting, WSClientState.Closing:
    discard
  of WSClientState.Open:
    if client.callbacks.opened != nil:
      client.callbacks.opened(client)
  of WSClientState.Closed:
    if client.callbacks.closed != nil:
      client.callbacks.closed(client)

proc close*(client: WebSocketClient) =
  # NOTE: Will the easy instance destroy itself? (I'm not sure if =destroy is called after this properly so there's a small chance it might end up leaking. Gotta verify that though)
  client.enterState(WSClientState.Closed)

proc failure*(client: WebSocketClient, message: string) =
  client.close()

  if client.callbacks.error != nil:
    client.callbacks.error(client, message)
