## JavaScript URL API - uses nim-url for URL parsing as per WHATWG
##
## Copyright (C) 2024-2025 Trayambak Rai (xtrayambak at disroot dot org)

import std/[options, logging]
import
  components/js/runtime/[arguments, types, atom_helpers, bridge, construction],
  components/js/runtime/abstract/coercion,
  components/js/stdlib/errors,
  components/js/stdlib/types/std_string_type,
  components/js/runtime/vm/atom
import pkg/[results, shakar, url]

type JSURL = object
  host*: string
  hostname*: string
  pathname*: string
  port*: int
  protocol*: string
  search*: string
  href*: string
  origin*: string
  source*: string
  hash*: string

proc transposeUrlToObject*(runtime: Runtime, parsed: URL, source: string): JSValue =
  var url = runtime.createObjFromType(JSURL)

  if *parsed.hostname:
    url["hostname"] = runtime.newJSString(&parsed.hostname)

  url["pathname"] = runtime.newJSString(parsed.pathname)

  if *parsed.port:
    url["port"] = integer(runtime, &parsed.port)

  url["protocol"] = runtime.newJSString(parsed.scheme & ':')

  if *parsed.query:
    url["search"] = runtime.newJSString(&parsed.query)

  url["source"] = runtime.newJSString(source)
  url["origin"] = runtime.newJSString(serialize(parsed))

  if *parsed.fragment:
    url["hash"] = runtime.newJSString('#' & &parsed.fragment)

  ensureMove(url)

proc toNativeURL*(runtime: Runtime, obj: JSValue): url.URL =
  var target: URL
  target.hostname = some(runtime.ToString(runtime.getProperty(obj, "hostname")))
  target.pathname = runtime.ToString(runtime.getProperty(obj, "pathname"))

  let
    portOpt = runtime.getProperty(obj, "port")
    queryOpt = runtime.getProperty(obj, "search")
    fragOpt = runtime.getProperty(obj, "hash")

  target.nonSpecialScheme = runtime.ToString(runtime.getProperty(obj, "protocol"))
  if target.scheme == "http":
    target.schemeType = SchemeType.Http
  elif target.scheme == "https":
    target.schemeType = SchemeType.Https
  elif target.scheme == "ws":
    target.schemeType = SchemeType.Ws
  elif target.scheme == "wss":
    target.schemeType = SchemeType.Wss
  elif target.scheme == "file":
    target.schemeType = SchemeType.File
  elif target.scheme == "ftp":
    target.schemeType = SchemeType.Ftp
  else:
    target.schemeType = SchemeType.NotSpecial

  if not portOpt.isUndefined:
    target.port = some(uint16(runtime.ToNumber(portOpt)))
  # else:
  #  target.port = defaultPort(target.scheme)

  if not queryOpt.isUndefined:
    target.query = some(runtime.ToString(runtime.getProperty(obj, "search")))

  if not fragOpt.isUndefined:
    target.fragment = some(runtime.ToString(runtime.getProperty(obj, "hash")))

  ensureMove(target)

proc generateStdIR*(runtime: Runtime) =
  info "url: generating IR interfaces"

  runtime.registerType("URL", JSURL)

  # URL constructor (`new URL()` syntax)
  runtime.defineConstructor(
    "URL",
    proc() =
      var osource: Option[JSValue]

      if (;
        osource = runtime.argument(
          1, true,
          "URL constructor: At least 1 argument required, but only {nargs} passed",
        )
        !osource
      ):
        return

      let source = &ensureMove(osource)

      if not runtime.isA(source, JSString):
        runtime.typeError(
          "URL constructor: " & runtime.ToString(source) & " is not a valid URL."
        )
        return

      let
        str = runtime.ToString(source)
        parsed = tryParseUrl(str)

      if !parsed:
        runtime.typeError($parsed.error())
      else:
        ret transposeUrlToObject(runtime, &parsed, str)
    ,
  )

  # URL.parse()
  runtime.defineFn(
    JSURL,
    "parse",
    proc() =
      var osource: Option[JSValue]

      if (;
        osource = runtime.argument(
          1, true, "URL.new: At least 1 argument required, but only {nargs} passed"
        )
        !osource
      ):
        return

      let source = &ensureMove(osource)

      if not runtime.isA(source, JSString):
        ret null(runtime)

      let
        str = runtime.ToString(source)
        parsed = tryParseURL(str)

      if *parsed:
        ret transposeUrlToObject(runtime, &parsed, str)
      else:
        ret JSURL()
    ,
  )
