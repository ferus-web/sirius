## WebSocket client implementation
## 
## For the original license, check components/net/ws/WHISKY-LICENSE.md
## 
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import std/[options, strutils, strformat]
import pkg/[chronicles, url, shakar]
import
  components/net/core,
  components/net/ws/types,
  components/net/loader/[core, types],
  components/impure/libcurl

logScope:
  topics = "net/ws/client"

proc newWebSocket*(loader: ResourceLoader, url: URL): WebSocketClient =
  ## Opens a new WebSocket connection.

  let client = WebSocketClient(state: WSClientState.Connecting)
  var errorBuff = newString(256)
  let handle = loader.createAdhocInstance(errorBuff)

  discard handle.curl_easy_setopt(CURLOPT_CONNECT_ONLY, 2)

  info "Fire WebSocket upgrade request", url = url
  discard loader.getAsyncStream(
    url,
    handle = handle,
    finalize = proc(resp: Response, err: TransportError) =
      if err.kind != TransportErrorKind.None:
        warn "Error while upgrading to WebSocket", kind = err.kind
        client.failure(&"Cannot upgrade transport to WebSocket: {err.kind}")
        return

      if resp.code != 101:
        client.failure(&"Got invalid WebSocket upgrade response code: {resp.code}")
        return

      client.enterState(WSClientState.Open),
  )

  client
