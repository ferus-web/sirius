## Implementation of `navigator`
## https://html.spec.whatwg.org/#the-navigator-object
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/cpuinfo
import components/js/runtime/prelude
import pkg/chronicles

logScope:
  topics = "html/navigator"

type JSNavigator* = object
  ## Instances of Navigator represent the identity and state of the user agent (the client). It has also been used as a generic global under which various APIs are located, but this is not precedent to build upon. Instead use the WindowOrWorkerGlobalScope mixin or equivalent.

  # https://html.spec.whatwg.org/#client-identification
  appCodeName*: string
  appName*: string
  appVersion*: string
  platform*: string
  product*: string
  productSub*: string
  userAgent*: string
  vendor*: string
  vendorSub*: string

  # https://html.spec.whatwg.org/#navigator.online
  onLine*: bool

  # https://html.spec.whatwg.org/#cookies
  cookieEnabled*: bool

  # https://html.spec.whatwg.org/#navigator.hardwareconcurrency
  hardwareConcurrency*: int64

proc generateGlobal*(runtime: Runtime) =
  discard runtime.setGlobal(
    "navigator",
    JSNavigator(
      # TODO: We should report accurate values here, eventually.
      appCodeName: "Mozilla",
      appName: "Netscape",
      appVersion: "0.1.0",
      platform: "Linux x86_64",
      product: "Gecko",
      productSub: "20100101",
      userAgent:
        "Mozilla/5.0 Sirius (+https://git.xtrayambak.xyz/ferus-web/sirius; Wayland; Linux x86_64; rv: 0.1.0)",
      vendor: "",
      vendorSub: "",

      # TODO: Maybe we can make this a getter that calls into platform-specific interfaces like NetworkManager to check stuff?
      onLine: true,
      cookieEnabled: true,
      hardwareConcurrency: countProcessors(),
        # NOTE: This is probably very fingerprintable. Maybe in the future we can spoof this if needed?
    ),
  )

proc generateBindings*(runtime: Runtime) =
  runtime.registerType(name = "Navigator", prototype = JSNavigator)
  runtime.definePrototypeFn(
    JSNavigator,
    "registerProtocolHandler",
    proc(this: JSValue) =
      # https://html.spec.whatwg.org/#dom-navigator-registerprotocolhandler
      const ErrorMessage =
        "navigator.registerProtocolHandler() expects 2 arguments, got {nargs}"

      let
        scheme =
          runtime.ToString(runtime.argument(1, required = true, message = ErrorMessage))
        url =
          runtime.ToString(runtime.argument(2, required = true, message = ErrorMessage))

      warn "IMPLEMENTME: Navigator.registerProtocolHandler()",
        scheme = scheme, url = url
    ,
  )

  runtime.definePrototypeFn(
    JSNavigator,
    "unregisterProtocolHandler",
    proc(this: JSValue) =
      # https://html.spec.whatwg.org/#dom-navigator-unregisterprotocolhandler
      const ErrorMessage =
        "navigator.unregisterProtocolHandler() expects 2 arguments, got {nargs}"

      let
        scheme =
          runtime.ToString(runtime.argument(1, required = true, message = ErrorMessage))
        url =
          runtime.ToString(runtime.argument(2, required = true, message = ErrorMessage))

      warn "IMPLEMENTME: Navigator.unregisterProtocolHandler()",
        scheme = scheme, url = url
    ,
  )
