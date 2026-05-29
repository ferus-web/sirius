## Core routines for the networking stack
##
## Largely derived from relay: https://github.com/planetis-m/relay

import std/[deques, locks, tables, streams]
import
  components/impure/libcurl,
  components/net/[http_headers, curl_wrapper],
  components/os/threads
import pkg/chronicles

export http_headers

logScope:
  topics = "net/core"

const
  MultiWaitMaxMs = 250
  DefaultConnectTimeoutMs = 10_000

type
  HttpVerb* {.pure, size: sizeof(uint8).} = enum
    Get = "GET"
    Post = "POST"
    Put = "PUT"
    Patch = "PATCH"
    Delete = "DELETE"
    Head = "HEAD"

  TransportErrorKind* {.pure, size: sizeof(uint8).} = enum
    None
    Timeout
    Network
    DNS
    TLS
    Canceled
    Protocol
    Internal

  TransportError* = object
    kind*: TransportErrorKind
    message*: string
    curlCode*: int

  RequestInfo* = object
    verb*: HttpVerb
    url*: string
    requestId*: int64

  Response* = object
    code*: int
    url*: string
    headers*: HttpHeaders
    body*: BodyWriterContext
    request*: RequestInfo

  RequestSpec* = object
    verb*: HttpVerb
    url*: string
    headers*: HttpHeaders
    body*: string
    requestId*: int64
    timeoutMs*: int
    writerKind*: BodyWriterKind

  RequestResult* = tuple[response: Response, error: TransportError]
  RequestResults* = seq[RequestResult]

  RequestBatch* = object
    requests: seq[RequestSpec]

  RequestWrap = ref object
    verb: HttpVerb
    url: string
    headers: HttpHeaders
    body: string
    requestId: int64
    timeoutMs: int
    responseBody: BodyWriterContext
    responseHeadersRaw: string
    easy: Easy
    curlHeaders: Slist

  NetworkClientObj = object
    lock: Lock
    wakeCond: Cond
    resultCond: Cond
    thread: Thread[ptr NetworkClientObj] # break cycle
    workerRunning: bool
    closeRequested: bool
    abortRequested: bool
    closed: bool
    maxInFlight: int
    defaultTimeoutMs: int
    maxRedirects: int
    multi: Multi
    availableEasy: seq[Easy]
    queue: Deque[RequestWrap]
    inFlight: Table[pointer, RequestWrap]
    readyResults: Deque[RequestResult]
    userAgent: string

  BodyWriterKind* {.pure, size: sizeof(uint8).} = enum
    SyncString
    AsyncStream

  BodyWriterContext* = ref object
    case kind*: BodyWriterKind
    of BodyWriterKind.SyncString:
      str*: ptr string
    of BodyWriterKind.AsyncStream:
      stream*: StringStream

  NetworkClient* = ref NetworkClientObj

proc noTransportError(): TransportError {.inline.} =
  TransportError(kind: TransportErrorKind.None, message: "", curlCode: 0)

proc newTransportError(
    kind: TransportErrorKind, message: sink string, curlCode = 0
): TransportError {.inline.} =
  TransportError(kind: kind, message: message, curlCode: curlCode)

proc classifyTransportError(curlCode: CURLcode): TransportErrorKind {.inline.} =
  case curlCode
  of CURLE_OPERATION_TIMEDOUT: TransportErrorKind.Timeout
  of CURLE_COULDNT_RESOLVE_PROXY, CURLE_COULDNT_RESOLVE_HOST: TransportErrorKind.DNS
  of CURLE_SSL_CONNECT_ERROR, CURLE_PEER_FAILED_VERIFICATION: TransportErrorKind.TLS
  of CURLE_ABORTED_BY_CALLBACK: TransportErrorKind.Canceled
  else: TransportErrorKind.Network

proc bodyWriteCb(
    buffer: ptr char, size, nitems: csize_t, userdata: pointer
): csize_t {.cdecl.} =
  let total = int(size * nitems)
  if total <= 0:
    result = 0
  else:
    let body = cast[BodyWriterContext](userdata)
    if body.isNil:
      warn "BodyWriterContext is NULL? Ignoring."
      result = csize_t(total)
    else:
      debug "Write into body buffer",
        kind = body.kind, total = total, size = size, nitems = nitems
      case body.kind
      of BodyWriterKind.SyncString:
        let start = body.str[].len
        body.str[].setLen(start + total)
        copyMem(addr body.str[][start], buffer, total)
        result = csize_t(total)
      of BodyWriterKind.AsyncStream:
        body.stream.writeData(buffer, total)
        result = csize_t(total)

proc headerWriteCb(
    buffer: ptr char, size, nitems: csize_t, userdata: pointer
): csize_t {.cdecl.} =
  let total = int(size * nitems)
  if total <= 0:
    result = 0
  else:
    let headers = cast[ptr string](userdata)
    if headers.isNil:
      result = csize_t(total)
    else:
      let start = headers[].len
      headers[].setLen(start + total)
      copyMem(addr headers[][start], buffer, total)
      result = csize_t(total)

proc newResponse(request: RequestWrap): Response {.inline.} =
  Response(
    code: 0,
    url: request.url,
    headers: @[],
    body: request.responseBody,
    request: RequestInfo(
      verb: request.verb, url: move request.url, requestId: request.requestId
    ),
  )

proc storeCompletionLocked(client: NetworkClient, item: sink RequestResult) =
  client.readyResults.addLast(item)
  signal(client.resultCond)

proc configureEasy(client: NetworkClient, request: RequestWrap, easy: var Easy) =
  easy.reset()
  easy.setUrl(request.url)
  easy.setHttpVersion2Tls()

  easy.setMethod($request.verb)
  easy.setNoBody(request.verb == HttpVerb.Head)
  if request.body.len > 0:
    easy.setRequestBody(request.body)

  var headerList: Slist
  for header in request.headers:
    headerList.addHeader(header.name & ": " & header.value)
  request.curlHeaders = headerList
  easy.setHeaders(request.curlHeaders)

  easy.setWriteCallback(bodyWriteCb, cast[pointer](request.responseBody))
  easy.setHeaderCallback(headerWriteCb, cast[pointer](addr request.responseHeadersRaw))
  easy.setTimeoutMs(
    if request.timeoutMs > 0: request.timeoutMs else: client.defaultTimeoutMs
  )
  easy.setConnectTimeoutMs(DefaultConnectTimeoutMs)
  easy.setSslVerify(true, true)
  easy.setAcceptEncoding("gzip, deflate")
  easy.setFollowRedirects(true, client.maxRedirects)
  easy.setUserAgent(client.userAgent)

proc completionFromCurl(
    request: RequestWrap, curlCode: CURLcode, removeError: sink string
): RequestResult =
  result.response = newResponse(request)
  if removeError.len > 0:
    result.error = newTransportError(TransportErrorKind.Internal, removeError)
  elif curlCode != CURLE_OK:
    result.error = newTransportError(
      classifyTransportError(curlCode), $curl_easy_strerror(curlCode), int(curlCode)
    )
  else:
    try:
      result.response.code = request.easy.responseCode()
      let effective = request.easy.effectiveUrl()
      if effective.len > 0:
        result.response.url = effective
      result.response.headers = parseHeaders(request.responseHeadersRaw)
      result.response.body = move request.responseBody
      result.error = noTransportError()
    except CatchableError:
      result.error =
        newTransportError(TransportErrorKind.Internal, getCurrentExceptionMsg())

proc flushCanceledLocked(client: NetworkClient, message: string) =
  while client.queue.len > 0:
    let queued = client.queue.popFirst()
    client.storeCompletionLocked(
      (newResponse(queued), newTransportError(Canceled, message))
    )

  for req in values(client.inFlight):
    try:
      client.multi.removeHandle(req.easy)
    except CatchableError:
      discard
    client.availableEasy.add(move req.easy)
    client.storeCompletionLocked(
      (newResponse(req), newTransportError(Canceled, message))
    )
  client.inFlight.clear()

proc runEasyLoop(client: NetworkClient): bool =
  result = true
  try:
    discard client.multi.perform()
    discard client.multi.poll(MultiWaitMaxMs)
  except CatchableError:
    let loopError = getCurrentExceptionMsg()
    acquire(client.lock)
    while client.queue.len > 0:
      let queued = client.queue.popFirst()
      client.storeCompletionLocked(
        (newResponse(queued), newTransportError(Internal, loopError))
      )
    for req in values(client.inFlight):
      client.storeCompletionLocked(
        (newResponse(req), newTransportError(Internal, loopError))
      )
    client.inFlight.clear()
    client.abortRequested = true
    signal(client.wakeCond)
    release(client.lock)
    result = false

proc processDoneMessages(client: NetworkClient) =
  var msg: CURLMsg
  var msgsInQueue = 0
  while client.multi.tryInfoRead(msg, msgsInQueue):
    if msg.msg == CURLMSG_DONE:
      var request: RequestWrap
      let key = handleKey(msg)
      acquire(client.lock)
      discard client.inFlight.pop(key, request)
      release(client.lock)

      if request != nil:
        var removeError = ""
        try:
          client.multi.removeHandle(msg)
        except CatchableError:
          removeError = getCurrentExceptionMsg()

        let completion = completionFromCurl(request, msg.data.result, removeError)
        acquire(client.lock)
        client.availableEasy.add(move request.easy)
        client.storeCompletionLocked(completion)
        release(client.lock)

proc dispatchQueuedRequests(client: NetworkClient) =
  var done = false
  while not done:
    var request: RequestWrap
    var easy: Easy
    acquire(client.lock)
    if client.abortRequested or client.availableEasy.len == 0 or client.queue.len == 0:
      done = true
    else:
      request = client.queue.popFirst()
      easy = client.availableEasy.pop()
    release(client.lock)

    if not done:
      var dispatched = true
      var dispatchError = ""
      try:
        request.easy = move easy
        configureEasy(client, request, request.easy)
        client.multi.addHandle(request.easy)
      except CatchableError:
        dispatched = false
        dispatchError = getCurrentExceptionMsg()

      acquire(client.lock)
      if dispatched:
        client.inFlight[handleKey(request.easy)] = request
      else:
        client.availableEasy.add(move request.easy)
        client.storeCompletionLocked(
          (newResponse(request), newTransportError(Internal, dispatchError))
        )
      release(client.lock)

proc waitForWorkOrClose(client: NetworkClient): bool =
  result = true
  acquire(client.lock)
  while not client.abortRequested and not client.closeRequested and client.queue.len == 0 and
      client.inFlight.len == 0:
    wait(client.wakeCond, client.lock)

  if client.abortRequested:
    result = false
  elif client.closeRequested and client.queue.len == 0 and client.inFlight.len == 0:
    result = false
  release(client.lock)

proc workerMain(clientPtr: ptr NetworkClientObj) {.thread, raises: [].} =
  debug "Starting network worker"
  setThreadName("Network")

  let client = cast[NetworkClient](clientPtr)

  while true:
    dispatchQueuedRequests(client)

    acquire(client.lock)
    let hasInflight = client.inFlight.len > 0
    let shouldAbort = client.abortRequested
    release(client.lock)

    if shouldAbort:
      acquire(client.lock)
      flushCanceledLocked(client, "Canceled in abort")
      release(client.lock)
      break

    if hasInflight:
      if not runEasyLoop(client):
        break
      processDoneMessages(client)
    elif not waitForWorkOrClose(client):
      break

  acquire(client.lock)
  client.workerRunning = false
  signal(client.resultCond)
  release(client.lock)

proc newNetworkClient*(
    maxInFlight = 16, defaultTimeoutMs = 60_000, maxRedirects = 10, userAgent: string
): NetworkClient =
  initGlobal()

  result = NetworkClient(
    maxInFlight: max(1, maxInFlight),
    defaultTimeoutMs: max(1, defaultTimeoutMs),
    maxRedirects: max(0, maxRedirects),
    workerRunning: true,
    multi: initMulti(),
    queue: initDeque[RequestWrap](),
    readyResults: initDeque[RequestResult](),
    inFlight: initTable[pointer, RequestWrap](),
    availableEasy: @[],
    userAgent: userAgent,
  )

  initLock(result.lock)
  initCond(result.wakeCond)
  initCond(result.resultCond)

  for _ in 0 ..< result.maxInFlight:
    result.availableEasy.add(initEasy())

  createThread(result.thread, workerMain, cast[ptr NetworkClientObj](result))

proc close*(client: NetworkClient) =
  if client.isNil:
    return

  acquire(client.lock)
  if client.closed:
    release(client.lock)
  else:
    client.closeRequested = true
    signal(client.wakeCond)
    release(client.lock)
    joinThread(client.thread)

    acquire(client.lock)
    client.closed = true
    client.availableEasy.reset()
    client.queue.clear()
    client.inFlight.clear()
    client.readyResults.clear()
    release(client.lock)

    deinitCond(client.resultCond)
    deinitCond(client.wakeCond)
    deinitLock(client.lock)
    cleanupGlobal()

proc abort*(client: NetworkClient) =
  if client.isNil:
    return

  acquire(client.lock)
  if client.closed:
    release(client.lock)
  else:
    client.abortRequested = true
    client.closeRequested = true
    signal(client.wakeCond)
    release(client.lock)
    joinThread(client.thread)

    acquire(client.lock)
    client.closed = true
    client.availableEasy.reset()
    client.queue.clear()
    client.inFlight.clear()
    client.readyResults.clear()
    release(client.lock)

    deinitCond(client.resultCond)
    deinitCond(client.wakeCond)
    deinitLock(client.lock)
    cleanupGlobal()

proc hasRequests*(client: NetworkClient): bool =
  acquire(client.lock)
  result = client.queue.len > 0 or client.inFlight.len > 0
  release(client.lock)

proc numInFlight*(client: NetworkClient): int =
  acquire(client.lock)
  result = client.inFlight.len
  release(client.lock)

proc queueLen*(client: NetworkClient): int =
  acquire(client.lock)
  result = client.queue.len
  release(client.lock)

proc clearQueue*(client: NetworkClient) =
  acquire(client.lock)
  while client.queue.len > 0:
    let queued = client.queue.popFirst()
    client.storeCompletionLocked(
      (newResponse(queued), newTransportError(Canceled, "Canceled in clearQueue"))
    )
  release(client.lock)

proc clientIsBusy(client: NetworkClient): bool =
  acquire(client.lock)
  result =
    client.queue.len > 0 or client.inFlight.len > 0 or client.readyResults.len > 0
  release(client.lock)

proc wrapRequest(request: sink RequestSpec): RequestWrap {.inline.} =
  var wrapped = RequestWrap(
    verb: request.verb,
    url: move request.url,
    headers: move request.headers,
    body: move request.body,
    requestId: request.requestId,
    timeoutMs: request.timeoutMs,
    responseBody: BodyWriterContext(kind: request.writerKind),
    responseHeadersRaw: "",
    easy: default(Easy),
  )
  if wrapped.responseBody.kind == BodyWriterKind.AsyncStream:
    wrapped.responseBody.stream = newStringStream()

  ensureMove(wrapped)

proc startRequests*(client: NetworkClient, batch: var RequestBatch) =
  acquire(client.lock)
  if client.closed or client.closeRequested:
    release(client.lock)
    raise newException(IOError, "client is closed")

  for request in batch.requests.mitems:
    client.queue.addLast(wrapRequest(move request))
  batch.requests.setLen(0)

  signal(client.wakeCond)
  release(client.lock)

proc startRequest*(client: NetworkClient, request: sink RequestSpec) =
  acquire(client.lock)
  if client.closed or client.closeRequested:
    release(client.lock)
    raise newException(IOError, "client is closed")

  client.queue.addLast(wrapRequest(request))

  signal(client.wakeCond)
  release(client.lock)

proc waitForResult*(client: NetworkClient, outResult: var RequestResult): bool =
  acquire(client.lock)
  while client.readyResults.len == 0 and client.workerRunning:
    wait(client.resultCond, client.lock)

  if client.readyResults.len > 0:
    outResult = client.readyResults.popFirst()
    result = true
  else:
    result = false
  release(client.lock)

proc pollForResult*(client: NetworkClient, outResult: var RequestResult): bool =
  acquire(client.lock)
  if client.readyResults.len > 0:
    outResult = client.readyResults.popFirst()
    result = true
  else:
    result = false
  release(client.lock)

proc makeRequests*(client: NetworkClient, batch: var RequestBatch): RequestResults =
  if client.clientIsBusy():
    raise newException(IOError, "makeRequests requires an idle client")

  let expected = batch.requests.len
  client.startRequests(batch)
  result = @[]
  for _ in 0 ..< expected:
    var item: RequestResult
    if not client.waitForResult(item):
      raise newException(IOError, "client stopped before all responses arrived")
    result.add(item)

proc makeRequest*(client: NetworkClient, request: sink RequestSpec): RequestResult =
  if client.clientIsBusy():
    raise newException(IOError, "makeRequest requires an idle client")

  client.startRequest(request)
  if not client.waitForResult(result):
    raise newException(IOError, "client stopped before response arrived")

proc makeVerbRequest(
    client: NetworkClient,
    verb: HttpVerb,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    body: sink string = "",
    requestId = 0'i64,
    timeoutMs = 0,
    writerKind: BodyWriterKind = BodyWriterKind.SyncString,
): RequestResult {.inline.} =
  client.makeRequest(
    RequestSpec(
      verb: verb,
      url: url,
      headers: headers,
      body: body,
      requestId: requestId,
      timeoutMs: timeoutMs,
      writerKind: writerKind,
    )
  )

proc get*(
    client: NetworkClient,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    requestId = 0'i64,
    timeoutMs = 0,
): RequestResult =
  client.makeVerbRequest(HttpVerb.Get, url, headers, "", requestId, timeoutMs)

proc getStream*(
    client: NetworkClient,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    requestId = 0'i64,
    timeoutMs = 0,
): RequestResult =
  client.makeVerbRequest(
    HttpVerb.Get,
    url,
    headers,
    "",
    requestId,
    timeoutMs,
    writerKind = BodyWriterKind.AsyncStream,
  )

proc post*(
    client: NetworkClient,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    body: sink string = "",
    requestId = 0'i64,
    timeoutMs = 0,
): RequestResult =
  client.makeVerbRequest(HttpVerb.Post, url, headers, body, requestId, timeoutMs)

proc put*(
    client: NetworkClient,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    body: sink string = "",
    requestId = 0'i64,
    timeoutMs = 0,
): RequestResult =
  client.makeVerbRequest(HttpVerb.Put, url, headers, body, requestId, timeoutMs)

proc patch*(
    client: NetworkClient,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    body: sink string = "",
    requestId = 0'i64,
    timeoutMs = 0,
): RequestResult =
  client.makeVerbRequest(HttpVerb.Patch, url, headers, body, requestId, timeoutMs)

proc delete*(
    client: NetworkClient,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    requestId = 0'i64,
    timeoutMs = 0,
): RequestResult =
  client.makeVerbRequest(HttpVerb.Delete, url, headers, "", requestId, timeoutMs)

proc head*(
    client: NetworkClient,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    requestId = 0'i64,
    timeoutMs = 0,
): RequestResult =
  client.makeVerbRequest(HttpVerb.Head, url, headers, "", requestId, timeoutMs)

proc len*(batch: RequestBatch): int {.inline.} =
  batch.requests.len

proc `[]`*(batch: RequestBatch, i: int): lent RequestSpec =
  batch.requests[i]

proc addRequest*(
    batch: var RequestBatch,
    verb: HttpVerb,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    body: sink string = "",
    requestId = 0'i64,
    timeoutMs = 0,
) {.inline.} =
  batch.requests.add(
    RequestSpec(
      verb: verb,
      url: url,
      headers: headers,
      body: body,
      requestId: requestId,
      timeoutMs: timeoutMs,
    )
  )

proc get*(
    batch: var RequestBatch,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    requestId = 0'i64,
    timeoutMs = 0,
) =
  batch.addRequest(Get, url, headers, "", requestId, timeoutMs)

proc post*(
    batch: var RequestBatch,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    body: sink string = "",
    requestId = 0'i64,
    timeoutMs = 0,
) =
  batch.addRequest(Post, url, headers, body, requestId, timeoutMs)

proc put*(
    batch: var RequestBatch,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    body: sink string = "",
    requestId = 0'i64,
    timeoutMs = 0,
) =
  batch.addRequest(Put, url, headers, body, requestId, timeoutMs)

proc patch*(
    batch: var RequestBatch,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    body: sink string = "",
    requestId = 0'i64,
    timeoutMs = 0,
) =
  batch.addRequest(Patch, url, headers, body, requestId, timeoutMs)

proc delete*(
    batch: var RequestBatch,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    requestId = 0'i64,
    timeoutMs = 0,
) =
  batch.addRequest(Delete, url, headers, "", requestId, timeoutMs)

proc head*(
    batch: var RequestBatch,
    url: sink string,
    headers: sink HttpHeaders = emptyHttpHeaders(),
    requestId = 0'i64,
    timeoutMs = 0,
) =
  batch.addRequest(Head, url, headers, "", requestId, timeoutMs)
