import components/js/runtime/prelude
import pkg/[chronicles, shakar]

logScope:
  topics = "location"

type Location* = object

proc hrefGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Location.href getter"
  undefined(rt)

proc hrefSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Location.href setter"

proc originGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Location.origin getter"
  undefined(rt)

proc protocolGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Location.protocol getter"
  undefined(rt)

proc protocolSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Location.protocol setter"

proc hostGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Location.host getter"
  undefined(rt)

proc hostSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Location.host setter"

proc hostnameGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Location.hostname getter"
  undefined(rt)

proc hostnameSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Location.hostname setter"

proc portGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Location.port getter"
  undefined(rt)

proc portSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Location.port setter"

proc pathnameGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Location.pathname getter"
  undefined(rt)

proc pathnameSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Location.pathname setter"

proc searchGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Location.search getter"
  undefined(rt)

proc searchSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Location.search setter"

proc hashGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Location.hash getter"
  undefined(rt)

proc hashSetter(rt: Runtime, this: JSValue, value: JSValue) =
  warn "IMPLEMENTME: Location.hash setter"

proc ancestorOriginsGetter(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Location.ancestorOrigins getter"
  undefined(rt)

proc assign(rt: Runtime, this: JSValue, url: JSValue): JSValue =
  warn "IMPLEMENTME: Location::assign()", url = rt.ToString(url)
  undefined(rt)

proc replace(rt: Runtime, this: JSValue, url: JSValue): JSValue =
  warn "IMPLEMENTME: Location::replace()", url = rt.ToString(url)
  undefined(rt)

proc reload(rt: Runtime, this: JSValue): JSValue =
  warn "IMPLEMENTME: Location::reload()"
  undefined(rt)

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("Location", Location)
  runtime.defineAccessor(
    Location,
    "href",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret hrefGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        hrefSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Location,
    "origin",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret originGetter(rt = runtime, this = this)
    ),
  )
  runtime.defineAccessor(
    Location,
    "protocol",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret protocolGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        protocolSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Location,
    "host",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret hostGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        hostSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Location,
    "hostname",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret hostnameGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        hostnameSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Location,
    "port",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret portGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        portSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Location,
    "pathname",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret pathnameGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        pathnameSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Location,
    "search",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret searchGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        searchSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Location,
    "hash",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret hashGetter(rt = runtime, this = this)
      ,
      setter: proc(this: JSValue, value: JSValue) =
        hashSetter(rt = runtime, this, value),
    ),
  )
  runtime.defineAccessor(
    Location,
    "ancestorOrigins",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret ancestorOriginsGetter(rt = runtime, this = this)
    ),
  )

  runtime.definePrototypeFn(
    Location,
    "assign",
    proc(this: JSValue) =
      let url = &runtime.argument(1, required = true)
      ret assign(rt = runtime, this = this, url = url)
    ,
  )

  runtime.definePrototypeFn(
    Location,
    "replace",
    proc(this: JSValue) =
      let url = &runtime.argument(1, required = true)
      ret replace(rt = runtime, this = this, url = url)
    ,
  )

  runtime.definePrototypeFn(
    Location,
    "reload",
    proc(this: JSValue) =
      ret reload(rt = runtime, this = this)
    ,
  )
