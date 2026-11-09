## Sirius' embedding API and its routines
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[importutils, tables]
import ../webview/types

proc bindFn*(view: WebView, name: string, fn: EmbeddedFunctionCallback) =
  privateAccess(WebView)

  view.routedFns[name] = fn
