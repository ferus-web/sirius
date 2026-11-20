## Implementation of `XMLHttpRequest`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, strformat, strutils]
import components/dom/dom, components/js/runtime/prelude
import components/scripting/xhr/request_upload, components/scripting/dom/exception
import pkg/[chronicles, results, shakar, url]

import components/aux/pretty, tables

logScope:
  topics = "xhr/request"

type XMLHttpRequest* = object of request_upload.XMLHttpRequestEventTarget

const
  UploadObjectField = "uploadobject"
  DocumentField = "doc"

  Unsent*: uint16 = 0
  Opened*: uint16 = 1
  HeadersReceived*: uint16 = 2
  Loading*: uint16 = 3
  Done*: uint16 = 4

proc onreadystatechangeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.onreadystatechange getter"
  undefined(rt)

proc onreadystatechangeSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: XMLHttpRequest.onreadystatechange setter"

proc readyStateGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.readyState getter"
  undefined(rt)

proc timeoutGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.timeout getter"
  undefined(rt)

proc timeoutSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: XMLHttpRequest.timeout setter"

proc withCredentialsGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.withCredentials getter"
  undefined(rt)

proc withCredentialsSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: XMLHttpRequest.withCredentials setter"

proc uploadGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.upload getter"
  undefined(rt)

proc responseURLGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.responseURL getter"
  undefined(rt)

proc statusGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.status getter"
  undefined(rt)

proc statusTextGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.statusText getter"
  undefined(rt)

proc responseTypeGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.responseType getter"
  undefined(rt)

proc responseTypeSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: XMLHttpRequest.responseType setter"

proc responseGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.response getter"
  undefined(rt)

proc responseTextGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.responseText getter"
  undefined(rt)

proc responseXMLGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest.responseXML getter"
  undefined(rt)

proc newXMLHttpRequest*(rt: Runtime): XMLHttpRequest =
  XMLHttpRequest()

proc open(rt: Runtime, this: JSValue, meth: JSValue, url: JSValue): JSValue =
  ## https://xhr.spec.whatwg.org/#dom-xmlhttprequest-open

  func isForbiddenMethod(meth: string): bool {.inline.} =
    ## https://fetch.spec.whatwg.org/#forbidden-method
    ## A forbidden method is a method that is a byte-case-insensitive match for `CONNECT`, `TRACE`, or `TRACK`.
    cmpIgnoreCase(meth, "connect") == 0 or cmpIgnoreCase(meth, "trace") == 0 or
      cmpIgnoreCase(meth, "track") == 0

  func normalizeMethod(meth: string): string {.inline.} =
    ## https://fetch.spec.whatwg.org/#concept-method-normalize
    ## To normalize a method, if it is a byte-case-insensitive match for `DELETE`, `GET`, `HEAD`, `OPTIONS`, `POST`, or `PUT`, byte-uppercase it.

    if likely(
      cmpIgnoreCase(meth, "delete") == 0 or cmpIgnoreCase(meth, "get") == 0 or
        cmpIgnoreCase(meth, "head") == 0 or cmpIgnoreCase(meth, "options") == 0 or
        cmpIgnoreCase(meth, "post") == 0 or cmpIgnoreCase(meth, "put") == 0
    ):
      return toUpperAscii(meth)

    meth

  # TODO: 1. If this’s relevant global object is a Window object and its associated Document is not fully active, then throw an "InvalidStateError" DOMException. 
  discard

  # TODO: 2. If method is not a method, then throw a "SyntaxError" DOMException. 
  let methStr = rt.ToString(meth)

  # 3. If method is a forbidden method, then throw a "SecurityError" DOMException. 
  if isForbiddenMethod(methStr):
    rt.throwDomException(
      DOMExceptionCode.Security, &"Forbidden request method '{methStr}'"
    )
    return

  # 4. Normalize method.
  let meth = normalizeMethod(methStr)

  # 5. Let parsedURL be the result of encoding-parsing a URL url, relative to this’s relevant settings object.
  let parsedURLOpt = tryParseURL(
    rt.ToString(url),
    some((&getPrivateObject(&this.getHiddenField(DocumentField), dom.Document)).url),
  ) # FIXME: This is a HACK.

  # 6. If parsedURL is failure, then throw a "SyntaxError" DOMException. 
  if !parsedURLOpt:
    rt.throwDomException(
      DOMExceptionCode.Syntax, &"Cannot parse URL: {parsedURLOpt.error()}"
    )
    return

  # 7. If the async argument is omitted, set async to true, and set username and password to null.
  let async = true

  # 8. If parsedURL’s host is non-null: 
  let parsedURL = &parsedURLOpt

  var username, password: string
  if *parsedURL.hostname:
    # 1. If the username argument is not null, set the username given parsedURL and username.
    if parsedURL.username.len > 0:
      username = parsedURL.username

    # 2. If the password argument is not null, set the password given parsedURL and password. 
    if parsedURL.password.len > 0:
      password = parsedURL.password

  # 9. If async is false, the current global object is a Window object, and either this’s timeout is not 0 or this’s response type is not the empty string, then throw an "InvalidAccessError" DOMException. 
  if not async:
    # TODO: Implement the remaining conditions above and whatnot
    rt.throwDomException(DOMExceptionCode.InvalidAccess, "Request must be asynchronous")
    return

  # TODO: Implement this
  warn "IMPLEMENTME: XMLHttpRequest::open() steps 10-12"

proc open(
    rt: Runtime,
    this: JSValue,
    meth: JSValue,
    url: JSValue,
    async: bool,
    username: JSValue,
    password: JSValue,
): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest::open()",
    meth = rt.ToString(meth),
    url = rt.ToString(url),
    async = async,
    username = rt.ToString(username),
    password = rt.ToString(password)
  undefined(rt)

proc setRequestHeader(
    rt: Runtime, this: JSValue, name: JSValue, value: JSValue
): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest::setRequestHeader()",
    name = rt.ToString(name), value = rt.ToString(value)
  undefined(rt)

proc send(rt: Runtime, this: JSValue, body: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest::send()", body = rt.ToString(body)
  undefined(rt)

proc abort(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest::abort()"
  undefined(rt)

proc getResponseHeader(rt: Runtime, this: JSValue, name: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest::getResponseHeader()", name = rt.ToString(name)
  undefined(rt)

proc getAllResponseHeaders(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest::getAllResponseHeaders()"
  undefined(rt)

proc overrideMimeType(rt: Runtime, this: JSValue, mime: JSValue): JSValue =
  warn "IMPLEMENTME: XMLHttpRequest::overrideMimeType()", mime = rt.ToString(mime)
  undefined(rt)

proc generateBindings*(runtime: Runtime, doc: JSValue) =
  runtime.registerType("XMLHttpRequest", XMLHttpRequest)
  runtime.defineConstructor(
    "XMLHttpRequest",
    proc() =
      ## https://xhr.spec.whatwg.org/#dom-xmlhttprequest

      # 1. Set this’s upload object to a new XMLHttpRequestUpload object. 
      let
        this = runtime.createObjFromType(XMLHttpRequest)
        requestUpload = runtime.createObjFromType(XMLHttpRequestUpload)

      this.setHiddenField(UploadObjectField, runtime.wrap(hidden(requestUpload)))

      # HACK: We're just storing the document global's pointer here for now.
      this.setHiddenField(DocumentField, doc)

      ret this
    ,
  )

  runtime.setProperty(XMLHttpRequest, "UNSENT", Unsent)
  runtime.setProperty(XMLHttpRequest, "OPENED", Opened)
  runtime.setProperty(XMLHttpRequest, "HEADERS_RECEIVED", HeadersReceived)
  runtime.setProperty(XMLHttpRequest, "LOADING", Loading)
  runtime.setProperty(XMLHttpRequest, "DONE", Done)
  runtime.defineAccessor(
    XMLHttpRequest,
    "onreadystatechange",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret onreadystatechangeGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        onreadystatechangeSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequest,
    "readyState",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret readyStateGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequest,
    "timeout",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret timeoutGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        timeoutSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequest,
    "withCredentials",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret withCredentialsGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        withCredentialsSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequest,
    "upload",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret uploadGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequest,
    "responseURL",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret responseURLGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequest,
    "status",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret statusGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequest,
    "statusText",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret statusTextGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequest,
    "responseType",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret responseTypeGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        responseTypeSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequest,
    "response",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret responseGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequest,
    "responseText",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret responseTextGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    XMLHttpRequest,
    "responseXML",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret responseXMLGetter(rt = runtime, this = this)
    ),
  )

  runtime.definePrototypeFn(
    XMLHttpRequest,
    "open",
    proc(this: JSValue) =
      # TODO: make overload resolution in niskriya work
      let meth = &runtime.argument(1, required = true)
      let url = &runtime.argument(2, required = true)
      ret open(rt = runtime, this = this, meth = meth, url = url)
    ,
  )

  #[ runtime.definePrototypeFn(
    XMLHttpRequest,
    "open",
    proc(this: JSValue) =
      let meth = &runtime.argument(1, required = true)
      let url = &runtime.argument(2, required = true)
      let async = &getBool(&runtime.argument(3, required = true))
      let username = &runtime.argument(4, required = false)
      let password = &runtime.argument(5, required = false)
      ret open(
        rt = runtime,
        this = this,
        meth = meth,
        url = url,
        async = async,
        username = username,
        password = password,
      )
    ,
  ) ]#

  runtime.definePrototypeFn(
    XMLHttpRequest,
    "setRequestHeader",
    proc(this: JSValue) =
      let name = &runtime.argument(1, required = true)
      let value = &runtime.argument(2, required = true)
      ret setRequestHeader(rt = runtime, this = this, name = name, value = value)
    ,
  )

  runtime.definePrototypeFn(
    XMLHttpRequest,
    "send",
    proc(this: JSValue) =
      let body = &runtime.argument(1, required = false)
      ret send(rt = runtime, this = this, body = body)
    ,
  )

  runtime.definePrototypeFn(
    XMLHttpRequest,
    "abort",
    proc(this: JSValue) =
      ret abort(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    XMLHttpRequest,
    "getResponseHeader",
    proc(this: JSValue) =
      let name = &runtime.argument(1, required = true)
      ret getResponseHeader(rt = runtime, this = this, name = name)
    ,
  )

  runtime.definePrototypeFn(
    XMLHttpRequest,
    "getAllResponseHeaders",
    proc(this: JSValue) =
      ret getAllResponseHeaders(rt = runtime, this = this)
    ,
  )

  runtime.definePrototypeFn(
    XMLHttpRequest,
    "overrideMimeType",
    proc(this: JSValue) =
      let mime = &runtime.argument(1, required = true)
      ret overrideMimeType(rt = runtime, this = this, mime = mime)
    ,
  )
