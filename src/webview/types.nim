## Types for WebView
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import pkg/surfer/app
import pkg/[chronicles, nanovg]
import
  components/gfx/types,
  components/html/dom,
  components/style/types,
  components/layout/[output_manager, types],
  components/os/fonts

logScope:
  topics = "webview/types"

type
  WebViewObj = object
    app*: App
    renderCtx*: RenderingContext
    fontProvider*: FontProvider

    dom*: Document

    stylesheet*: Stylesheet
    styleMap*: StyleMap
    tree*: LayoutNode

    outputManager*: OutputManager

  WebView* = ref WebViewObj

proc `=destroy`*(view: WebViewObj) =
  debug "~WebView()"
