## Types for WebView
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[tables, options]
import pkg/surfer/app
import pkg/[chronicles, nanovg, pixie, url, vmath]
import
  components/gfx/types,
  components/dom/dom,
  components/html/parser,
  components/style/types,
  components/layout/[output_manager, types],
  components/os/[assets, fonts],
  components/net/core

logScope:
  topics = "webview/types"

type
  WebViewOpts* = object
    disableImageLoading*, disableExternalStylesheets*, disableStyling*: bool

  WebViewObj = object
    app*: App
    renderCtx*: RenderingContext
    opts*: WebViewOpts

    fontProvider*: FontProvider
    assetProvider*: AssetProvider

    dom*: Document
    target*: URL

    stylesheet*: Stylesheet
    styleMap*: StyleMap
    tree*: LayoutNode

    outputManager*: OutputManager

    net*: NetworkClient

    style*: string

    cursor*: vmath.Vec2
    focusedElement*: Option[LayoutNode]

    imageCache*: TableRef[string, pixie.Image]
    failedPlaceholderImage*: pixie.Image

  WebView* = ref WebViewObj

proc `=destroy`*(view: WebViewObj) =
  debug "~WebView()"
