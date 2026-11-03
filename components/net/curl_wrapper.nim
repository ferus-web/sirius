## High-level wrapper for libcurl
## 
## Copyright (C) 2026 Trayambak Rai
## Copyright (c) 2026 Antonis Geralis
## Copyright (c) 2023 Ryan Oldenburg
import std/options
import components/impure/libcurl
import pkg/[shakar, results]

export CurlMsgType, CURLMsg

type
  Easy* = object
    raw*: CURL
    errorBuf: string

  Multi* = object
    raw*: CURLM

  Slist* = object
    raw: ptr curl_slist

  RawUrl* = object
    raw: CURLU
    rc: uint8

proc `=destroy`(easy: Easy) =
  if easy.raw != nil:
    curl_easy_cleanup(easy.raw)
  `=destroy`(easy.errorBuf)

proc `=destroy`*(multi: Multi) =
  if multi.raw != nil:
    discard curl_multi_cleanup(multi.raw)

proc `=destroy`*(list: Slist) =
  if list.raw != nil:
    curl_slist_free_all(list.raw)

proc `=destroy`*(url: var RawUrl) =
  discard "NOTE: Curl_URL lifecycles are too complex to be represented as destructors."

proc `=wasMoved`*(easy: var Easy) =
  easy.raw = nil
  `=wasMoved`(easy.errorBuf)

proc `=wasMoved`*(multi: var Multi) =
  multi.raw = nil

proc `=wasMoved`*(list: var Slist) =
  list.raw = nil

proc `=wasMoved`*(url: var RawUrl) =
  discard

proc `=copy`*(dest: var RawUrl, src: RawUrl) {.error.}

proc `=sink`*(dest: var RawUrl, src: RawUrl) =
  `=destroy`(dest)
  dest.raw = src.raw

proc `=dup`*(src: Easy): Easy {.error.}
proc `=dup`*(src: Multi): Multi {.error.}
proc `=dup`*(src: Slist): Slist {.error.}
proc `=dup`*(src: RawUrl): RawUrl =
  RawUrl(raw: curl_url_dup(src.raw))

proc `=copy`*(dest: var Easy, src: Easy) {.error.}
proc `=copy`*(dest: var Multi, src: Multi) {.error.}
proc `=copy`*(dest: var Slist, src: Slist) {.error.}

proc `=sink`*(dest: var Easy, src: Easy) =
  `=destroy`(dest)
  dest.raw = src.raw
  `=sink`(dest.errorBuf, src.errorBuf)

proc `=sink`*(dest: var Multi, src: Multi) =
  `=destroy`(dest)
  dest.raw = src.raw

proc `=sink`*(dest: var Slist, src: Slist) =
  `=destroy`(dest)
  dest.raw = src.raw

proc checkCurl(
    code: CURLcode, context: static string
): Result[void, string] {.noinline.} =
  case code
  of CURLE_OK:
    ok()
  else:
    err($curl_easy_strerror(code))

proc checkMulti(
    code: CURLMcode, context: static string
): Result[void, string] {.noinline.} =
  case code
  of CURLM_OK:
    ok()
  else:
    err($curl_multi_strerror(code))

proc initEasy*(): Easy =
  # TODO: It's painfully difficul to wrap this in an Option, so we're just going to panic upon failure, since this should ideally never fail.
  let handle = Easy(raw: curl_easy_init(), errorBuf: newString(256))
  if handle.raw == nil:
    raise newException(Defect, "Failed to initialize Easy instance")

  discard curl_easy_setopt(handle.raw, CURLOPT_ERRORBUFFER, handle.errorBuf.cstring)
  discard curl_easy_setopt(handle.raw, CURLOPT_NOSIGNAL, clong(1))

  handle

proc initMulti*(): Multi =
  result = Multi(raw: curl_multi_init())
  if result.raw == nil:
    raise newException(Defect, "curl_multi_init failed")

  if (
    let code = checkMulti(
      curl_multi_setopt(result.raw, CURLMOPT_PIPELINING, CURLPIPE_MULTIPLEX),
      "CURLMOPT_PIPELINING failed",
    )
    !code
  ):
    raise newException(Defect, code.error())

proc initGlobal*() =
  if (
    let code = checkCurl(curl_global_init(culong(3)), "curl_global_init failed")
    !code
  ):
    raise newException(Defect, "Failed to initialize libcURL: " & code.error())

proc cleanupGlobal*() =
  curl_global_cleanup()

proc addHandle*(multi: var Multi, easy: Easy): Result[void, string] =
  checkMulti(curl_multi_add_handle(multi.raw, easy.raw), "curl_multi_add_handle failed")

proc removeHandle*(multi: var Multi, easy: Easy): Result[void, string] =
  checkMulti(
    curl_multi_remove_handle(multi.raw, easy.raw), "curl_multi_remove_handle failed"
  )

proc removeHandle*(multi: var Multi, msg: CURLMsg): Result[void, string] =
  checkMulti(
    curl_multi_remove_handle(multi.raw, msg.easy_handle),
    "curl_multi_remove_handle failed",
  )

proc perform*(multi: var Multi): Result[int32, string] =
  var running: cint
  if (
    let code = checkMulti(
      curl_multi_perform(multi.raw, addr running), "curl_multi_perform failed"
    )
    !code
  ):
    return err(code.error())

  ok(cast[int32](running))

proc poll*(multi: var Multi, timeoutMs: int): Result[int32, string] =
  var numfds: cint
  if (
    let code = checkMulti(
      curl_multi_poll(multi.raw, nil, 0.cuint, timeoutMs.cint, addr numfds),
      "curl_multi_poll failed",
    )
    !code
  ):
    return err(code.error())

  ok(cast[int32](numfds))

proc tryInfoRead*(multi: var Multi, msg: var CURLMsg, msgsInQueue: var int): bool =
  var queue: cint
  let msgPtr = curl_multi_info_read(multi.raw, addr queue)
  msgsInQueue = int(queue)
  if msgPtr.isNil:
    result = false
  else:
    msg = msgPtr[]
    result = true

proc setUrl*(easy: var Easy, url: string): Result[void, string] =
  checkCurl(curl_easy_setopt(easy.raw, CURLOPT_URL, url.cstring), "CURLOPT_URL failed")

proc set*(
    url: var RawUrl, what: CURLUPart, str: sink string, flags: int32 = 0'i32
): Result[void, string] =
  if str.len < 1:
    return err("Cannot set URL component as empty string!")

  if (let err = curl_url_set(url.raw, what, str[0].addr, flags); err != CURLUE_OK):
    return err("Cannot set URL component: " & $curl_url_strerror(err))

  ok()

proc drop*(url: RawUrl) =
  curl_url_cleanup(url.raw)

proc setUrl*(easy: var Easy, handle: sink RawUrl): Result[void, string] =
  checkCurl(
    curl_easy_setopt(easy.raw, CURLOPT_CURLU, handle.raw), "CURLOPT_CURLU failed"
  )

proc setWriteCallback*(
    easy: var Easy, cb: curl_write_callback, userdata: pointer
): Result[void, string] =
  if (
    let code = checkCurl(
      curl_easy_setopt(easy.raw, CURLOPT_WRITEFUNCTION, cb),
      "CURLOPT_WRITEFUNCTION failed",
    )
    !code
  ):
    return code

  if (
    let code = checkCurl(
      curl_easy_setopt(easy.raw, CURLOPT_WRITEDATA, userdata),
      "CURLOPT_WRITEDATA failed",
    )
    !code
  ):
    return code

  ok()

proc setHeaderCallback*(
    easy: var Easy, cb: curl_write_callback, userdata: pointer
): Result[void, string] =
  if (
    let code = checkCurl(
      curl_easy_setopt(easy.raw, CURLOPT_HEADERFUNCTION, cb),
      "CURLOPT_HEADERFUNCTION failed",
    )
    !code
  ):
    return code

  if (
    let code = checkCurl(
      curl_easy_setopt(easy.raw, CURLOPT_HEADERDATA, userdata),
      "CURLOPT_HEADERDATA failed",
    )
    !code
  ):
    return code

  ok()

proc setRequestBody*(easy: var Easy, data: string): Result[void, string] =
  # WARNING: CURLOPT_POSTFIELDS does not copy this buffer; caller must keep data
  # alive and unchanged until the transfer is finished or the handle is removed.
  if (
    let code = checkCurl(
      curl_easy_setopt(easy.raw, CURLOPT_POSTFIELDS, data.cstring),
      "CURLOPT_POSTFIELDS failed",
    )
    !code
  ):
    return code

  if (
    let code = checkCurl(
      curl_easy_setopt(easy.raw, CURLOPT_POSTFIELDSIZE, clong(data.len)),
      "CURLOPT_POSTFIELDSIZE failed",
    )
    !code
  ):
    return code

  ok()

proc setMethod*(easy: var Easy, verb: string): Result[void, string] =
  checkCurl(
    curl_easy_setopt(easy.raw, CURLOPT_CUSTOMREQUEST, verb.cstring),
    "CURLOPT_CUSTOMREQUEST failed",
  )

proc setNoBody*(easy: var Easy, enabled: bool): Result[void, string] =
  checkCurl(
    curl_easy_setopt(easy.raw, CURLOPT_NOBODY, cast[clong](enabled)),
    "CURLOPT_NOBODY failed",
  )

proc setHeaders*(easy: var Easy, headers: Slist): Result[void, string] =
  checkCurl(
    curl_easy_setopt(easy.raw, CURLOPT_HTTPHEADER, headers.raw),
    "CURLOPT_HTTPHEADER failed",
  )

proc setUserAgent*(easy: var Easy, agent: string): Result[void, string] =
  checkCurl(
    curl_easy_setopt(easy.raw, CURLOPT_USERAGENT, cstring(agent)),
    "CURLOPT_USERAGENT failed",
  )

proc setFollowRedirects*(
    easy: var Easy, follow: bool, maxRedirects: int
): Result[void, string] =
  if (
    let code = checkCurl(
      curl_easy_setopt(easy.raw, CURLOPT_FOLLOWLOCATION, clong(if follow: 1 else: 0)),
      "CURLOPT_FOLLOWLOCATION failed",
    )
    !code
  ):
    return code
  if (
    let code = checkCurl(
      curl_easy_setopt(easy.raw, CURLOPT_MAXREDIRS, clong(maxRedirects)),
      "CURLOPT_MAXREDIRS failed",
    )
    !code
  ):
    return code

  ok()

proc setTimeoutMs*(easy: var Easy, timeoutMs: int): Result[void, string] =
  checkCurl(
    curl_easy_setopt(easy.raw, CURLOPT_TIMEOUT_MS, clong(timeoutMs)),
    "CURLOPT_TIMEOUT_MS failed",
  )

proc setConnectTimeoutMs*(easy: var Easy, timeoutMs: int): Result[void, string] =
  checkCurl(
    curl_easy_setopt(easy.raw, CURLOPT_CONNECTTIMEOUT_MS, clong(timeoutMs)),
    "CURLOPT_CONNECTTIMEOUT_MS failed",
  )

proc setSslVerify*(
    easy: var Easy, verifyPeer: bool, verifyHost: bool
): Result[void, string] =
  if (
    let code = checkCurl(
      curl_easy_setopt(
        easy.raw, CURLOPT_SSL_VERIFYPEER, clong(if verifyPeer: 1 else: 0)
      ),
      "CURLOPT_SSL_VERIFYPEER failed",
    )
    !code
  ):
    return code
  if (
    let code = checkCurl(
      curl_easy_setopt(
        easy.raw, CURLOPT_SSL_VERIFYHOST, clong(if verifyHost: 2 else: 0)
      ),
      "CURLOPT_SSL_VERIFYHOST failed",
    )
    !code
  ):
    return code

  ok()

proc setAcceptEncoding*(easy: var Easy, encoding: string): Result[void, string] =
  checkCurl(
    curl_easy_setopt(easy.raw, CURLOPT_ACCEPT_ENCODING, encoding.cstring),
    "CURLOPT_ACCEPT_ENCODING failed",
  )

proc setHttpVersion2Tls*(easy: var Easy): Result[void, string] =
  checkCurl(
    curl_easy_setopt(easy.raw, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2TLS),
    "CURLOPT_HTTP_VERSION failed",
  )

proc reset*(easy: var Easy): Result[void, string] =
  curl_easy_reset(easy.raw)
  if (
    let code = checkCurl(
      curl_easy_setopt(easy.raw, CURLOPT_ERRORBUFFER, easy.errorBuf.cstring),
      "CURLOPT_ERRORBUFFER failed",
    )
    !code
  ):
    return code

  if (
    let code = checkCurl(
      curl_easy_setopt(easy.raw, CURLOPT_NOSIGNAL, clong(1)), "CURLOPT_NOSIGNAL failed"
    )
    !code
  ):
    return code

  ok()

proc responseCode*(easy: Easy): Result[int, string] =
  # TODO: Use a HttpCode enum and put it somewhere in net.
  var code: clong
  if (
    let code = checkCurl(
      curl_easy_getinfo(easy.raw, CURLINFO_RESPONSE_CODE, addr code),
      "CURLINFO_RESPONSE_CODE failed",
    )
    !code
  ):
    return err(code.error())

  ok(int(code))

when defined(posix):
  proc getFd*(easy: Easy): Result[int32, string] =
    var fd: int32
    if (
      let code = checkCurl(
        curl_easy_getinfo(easy.raw, CURLINFO_ACTIVESOCKET, fd.addr),
        "CURLINFO_ACTIVESOCKET failed",
      )
      !code
    ):
      return err(code.error())

    ok(fd)

proc effectiveUrl*(easy: Easy): Result[string, string] =
  var urlPtr: cstring
  if (
    let code = checkCurl(
      curl_easy_getinfo(easy.raw, CURLINFO_EFFECTIVE_URL, addr urlPtr),
      "CURLINFO_EFFECTIVE_URL failed",
    )
    !code
  ):
    return err(code.error())

  ok($urlPtr)

proc addHeader*(list: var Slist, headerLine: string): Result[void, string] =
  list.raw = curl_slist_append(list.raw, headerLine.cstring)
  if list.raw.isNil:
    return err("curl_slist_append() failed")

  ok()

proc handleKey*(easy: Easy): pointer =
  easy.raw

proc handleKey*(msg: CURLMsg): pointer =
  msg.easy_handle

proc newRawUrl*(): RawUrl =
  RawUrl(raw: curl_url(), rc: 1)
