## `ResourceLoader` implementation
##
## This essentially just uses a web (no pun intended) of signalling callbacks to allow for asynchronous-ish resource loading.
##
## It just spins every frame to check if any request is complete, and calls the finalizer callback for it if it is.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[locks, streams, tables]
import pkg/[chronicles, shakar, url]
import
  components/net/[curl_wrapper, core],
  components/net/loader/types,
  components/impure/libcurl

logScope:
  topics = "loader"

proc getAsyncStream*(
    loader: ResourceLoader,
    url: url.URL,
    finalize: FinalizeCallback,
    headers: HTTPHeaders = emptyHttpHeaders(),
    timeoutMs = 0,
): RequestID =
  let requestId = loader.net.requestCount

  inc loader.net.requestCount
  let
    spec = RequestSpec(
      verb: HttpVerb.Get,
      url: url,
      headers: headers,
      body: newString(0),
      requestId: requestId,
      timeoutMs: timeoutMs,
      writerKind: BodyWriterKind.AsyncStream,
    )
    asset = PendingAsset(finalize: finalize)

  if not loader.net.fireVerbRequest(spec):
    # warn "Client is busy, adding request to try queue"
    loader.retryQueue.addLast((spec: spec, asset: asset))
  else:
    loader.pendingAssets[requestId] = asset

  requestId

proc getAsyncStream*(
    loader: ResourceLoader,
    url: url.URL,
    handle: libcurl.CURL,
    finalize: FinalizeCallback,
    headers: HttpHeaders = emptyHttpHeaders(),
    timeoutMs = 0,
): RequestID =
  let
    requestId = loader.net.requestCount
    asset = PendingAsset(finalize: finalize)

  loader.net.startRequestAdhoc(
    RequestSpec(
      verb: HttpVerb.Get,
      url: url,
      headers: headers,
      body: newString(0),
      requestId: requestId,
      timeoutMs: timeoutMs,
      writerKind: BodyWriterKind.AsyncStream,
    ),
    handle = handle,
  )

  inc loader.net.requestCount
  loader.pendingAssets[requestId] = asset

  requestId

proc poll*(loader: ResourceLoader) =
  var resp: RequestResult

  if loader.net.pollForResult(resp):
    let requestId = resp.response.request.requestId
    if requestId in loader.pendingAssets:
      if resp.response.body.kind == BodyWriterKind.AsyncStream:
        resp.response.body.stream.setPosition(0)

      loader.pendingAssets[requestId].finalize(
        response = resp.response, err = resp.error
      )
      loader.pendingAssets.del(requestId)

  if loader.retryQueue.len > 0:
    let queued = loader.retryQueue.popFirst()
    if not loader.net.fireVerbRequest(queued.spec):
      # warn "Client is busy, adding request to try queue"
      loader.retryQueue.addFirst(queued)
    else:
      loader.pendingAssets[queued.spec.requestId] = queued.asset

proc createAdhocInstance*(
    loader: ResourceLoader, errorBuffer: var string
): libcurl.CURL =
  let handle = curl_easy_init()
  discard curl_easy_setopt(handle, CURLOPT_ERRORBUFFER, errorBuffer[0].addr)
  discard curl_easy_setopt(handle, CURLOPT_NOSIGNAL, clong(1))

  handle

proc newResourceLoader*(net: NetworkClient): ResourceLoader =
  info "Starting resource loader"

  ResourceLoader(net: net)
