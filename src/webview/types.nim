## Types for WebView
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[deques, options, streams, tables]
import pkg/[chronicles, pixie, url, vmath]
import
  components/gfx/types,
  components/dom/[dom, tags],
  components/html/parser,
  components/style/types,
  components/layout/[output_manager, types],
  components/os/[assets, fonts],
  components/net/core,
  components/js/runtime/prelude as js,
  components/synapse/types
import ./[cookie_jar]

logScope:
  topics = "webview/types"

type
  WebViewOpts* = object
    disableImageLoading*, disableExternalStylesheets*, disableStyling*,
      disableScripting*: bool

  FinalizeCallback* = proc(response: Response, err: TransportError)

  PendingAsset* = object
    finalize*: FinalizeCallback

  ResourceLoader* = ref object
    net*: NetworkClient
    pendingAssets*: Table[RequestID, PendingAsset]

    retryQueue*: Deque[tuple[spec: RequestSpec, asset: PendingAsset]]

  WebRendererObj = object
    renderCtx*: RenderingContext

    client*: Client
    opts*: WebViewOpts

    fontProvider*: FontProvider
    assetProvider*: AssetProvider

    dom*: Document
    target*: URL
    realm*: js.Realm
    scripts*: seq[HTMLScriptElement]
    coreScript*: HTMLScriptElement

    stylesheet*: Stylesheet
    styleMap*: StyleMap
    tree*: LayoutNode

    outputManager*: OutputManager

    loader*: ResourceLoader

    style*: string

    cursor*: vmath.Vec2
    focusedElement*: Option[LayoutNode]
    keyboardFocusedElement*: Option[dom.Element]

    imageCache*: TableRef[string, pixie.Image]
    failedPlaceholderImage*: pixie.Image

    progress*: bool
      # FIXME: There's probably some DOM API we can implement that shares the same thing instead of this hack

    cookieJar*: CookieJar

    lastDmabufFd*: int32
    running*: bool

  WebRenderer* = ref WebRendererObj

  WebViewObj = object
    opts*: WebViewOpts
    master*: Master

  WebView* = ref WebViewObj

proc `=destroy`*(view: WebViewObj) =
  debug "~WebView()"
