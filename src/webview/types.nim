## Types for WebView
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[deques, options, streams, tables]
import pkg/surfer/app
import pkg/[chronicles, pixie, url, vmath]
import
  components/gfx/types,
  components/dom/dom,
  components/html/parser,
  components/style/types,
  components/layout/[output_manager, types],
  components/os/[assets, fonts],
  components/net/core,
  components/dom/tags

logScope:
  topics = "webview/types"

type
  WebViewOpts* = object
    disableImageLoading*, disableExternalStylesheets*, disableStyling*: bool

  FinalizeCallback* = proc(response: Response, err: TransportError)

  PendingAsset* = object
    finalize*: FinalizeCallback

  ResourceLoader* = ref object
    net*: NetworkClient
    pendingAssets*: Table[RequestID, PendingAsset]

    retryQueue*: Deque[tuple[spec: RequestSpec, asset: PendingAsset]]

  WebViewObj = object
    app*: App
    renderCtx*: RenderingContext
    opts*: WebViewOpts

    fontProvider*: FontProvider
    assetProvider*: AssetProvider

    dom*: Document
    target*: URL
    scripts*: seq[HTMLScriptElement]

    stylesheet*: Stylesheet
    styleMap*: StyleMap
    tree*: LayoutNode

    outputManager*: OutputManager

    loader*: ResourceLoader

    style*: string

    cursor*: vmath.Vec2
    focusedElement*: Option[LayoutNode]

    imageCache*: TableRef[string, pixie.Image]
    failedPlaceholderImage*: pixie.Image

  WebView* = ref WebViewObj

proc `=destroy`*(view: WebViewObj) =
  debug "~WebView()"
