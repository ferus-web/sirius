## Types for WebView
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options
import pkg/surfer/app
import pkg/[chronicles, nanovg, vmath]
import
  components/gfx/types,
  components/html/dom,
  components/style/types,
  components/layout/[output_manager, types],
  components/os/[assets, fonts],
  components/net/core

logScope:
  topics = "webview/types"

type
  WebViewObj = object
    app*: App
    renderCtx*: RenderingContext

    fontProvider*: FontProvider
    assetProvider*: AssetProvider

    dom*: Document

    stylesheet*: Stylesheet
    styleMap*: StyleMap
    tree*: LayoutNode

    outputManager*: OutputManager

    net*: NetworkClient

    style*: string

    cursor*: vmath.Vec2
    focusedElement*: Option[LayoutNode]

  WebView* = ref WebViewObj

proc `=destroy`*(view: WebViewObj) =
  debug "~WebView()"
