## Implementation of `navigator`
## https://html.spec.whatwg.org/#the-navigator-object
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/js/runtime/prelude

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

proc generateBindings*(runtime: Runtime) =
  runtime.registerType(name = "Navigator", prototype = JSNavigator)

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
        "Mozilla/5.0 Sirius (+https://github.com/ferus-web/sirius; Wayland; Linux x86_64; rv: 0.1.0)",
      vendor: "",
      vendorSub: "",
    ),
  )
