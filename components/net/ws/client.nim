## WebSocket client implementation
## 
## For the original license, check components/net/ws/WHISKY-LICENSE.md
## 
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import std/[options, strutils, strformat, streams]
import pkg/[chronicles, results, shakar, url]
import
  components/net/core,
  components/net/ws/types,
  components/net/loader/[core, types],
  components/impure/libcurl

logScope:
  topics = "net/ws/client"

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
  # TODO: Cleanup the libcurl handle too, it currently just leaks.
  client.enterState(WSClientState.Closed)

proc failure*(client: WebSocketClient, message: string) {.gcsafe.} =
  client.close()

  if client.callbacks.error != nil:
    client.callbacks.error(client, message)

proc getFd*(client: WebSocketClient): Result[int32, string] =
  var fd: int32

  if (
    let res = libcurl.curl_easy_getinfo(
      client.handle.raw, libcurl.CURLINFO_ACTIVESOCKET, fd.addr
    )
    res != libcurl.CURLE_OK or fd < 0'i32
  ):
    return err(
      &"Cannot get file descriptor of WebSocketClient: {libcurl.curl_easy_strerror(res)} (fd={fd})"
    )

  ok(fd)

proc feedTextFrame*(client: WebSocketClient, text: string) =
  if client.callbacks.textFrame != nil:
    client.callbacks.textFrame(client, text)

proc handleMessage*(client: WebSocketClient) =
  var buffer = newString(4096)
  var nread: int64
  var meta: ptr libcurl.curl_ws_frame

  let res = libcurl.curl_ws_recv(
    client.handle.raw, buffer[0].addr, cast[int64](buffer.len), nread.addr, meta.addr
  )
  if res != libcurl.CURLE_OK:
    client.failure(
      &"Failed to receive incoming message: {libcurl.curl_easy_strerror(res)}"
    )
    return

  buffer.setLen(nread)
  if meta != nil:
    if (meta.flags and cast[int32](libcurl.CURLWS_CLOSE)) != 0:
      client.close()

    if (meta.flags and cast[int32](libcurl.CURLWS_TEXT)) != 0:
      client.feedTextFrame(ensureMove(buffer))

proc send*(client: WebSocketClient, text: string): Result[void, string] =
  if client.state != WSClientState.Open:
    return err("WebSocket is not in an Open state")

  var sent: int64
  if text.len == 0:
    # TODO: Maybe make a wrapper for this
    let res = libcurl.curl_ws_send(
      client.handle.raw, nil, 0'i64, sent.addr, 0'u64, libcurl.CURLWS_TEXT
    )
    if res != libcurl.CURLE_OK:
      return err(&"Failed to send frame: {libcurl.curl_easy_strerror(res)}")
    return ok()

  let size = text.len
  while sent < size:
    var chunkSent: int64
    let remaining = size - sent

    let res = libcurl.curl_ws_send(
      client.handle.raw,
      cast[pointer](text[sent].addr),
      remaining,
      chunkSent.addr,
      0'u64,
      libcurl.CURLWS_TEXT,
    )
    if res != libcurl.CURLE_OK:
      return err(&"Failed to send frame: {libcurl.curl_easy_strerror(res)}")

    sent += chunkSent

  ok()

proc newWebSocket*(loader: ResourceLoader, url: URL): WebSocketClient =
  ## Opens a new WebSocket connection.

  var errorBuff = newString(256)
  let
    handle = loader.createAdhocInstance(errorBuff)
    client = WebSocketClient(
      state: WSClientState.Connecting, handle: handle, curlErrorBuffer: errorBuff
    )

  discard client.handle.raw.curl_easy_setopt(CURLOPT_CONNECT_ONLY, 2)

  info "Fire WebSocket upgrade request", url = url
  discard loader.getAsyncStream(
    url,
    handle = client.handle.raw,
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
