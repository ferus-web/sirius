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
  components/synapse/types,
  components/css/types
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

    lastCursorPredef*: CursorPredefined

  WebRenderer* = ref WebRendererObj

  TabID* = distinct uint32 # TODO: move this into the actual tab system?

  FrameDrawnCallback* = proc(view: WebView, tab: TabID)
  ReconstructCallback* = proc(view: WebView, tab: TabID)
  ResizeCallback* = proc(view: WebView, tab: TabID, size: vmath.IVec2)
  ProcessFaultCallback* = proc(view: WebView, tab: TabID, process: Process)
  PageTitleCallback* = proc(view: WebView, tab: TabID, title: string)
  CursorShapeCallback* = proc(view: WebView, tab: TabID, predef: CursorPredefined)
  AlertCallback* = proc(view: WebView, tab: TabID, message: Option[string])
  NavigationUpdateCallback* = proc(view: WebView, tab: TabID, target: url.URL)

  WebViewCallbacks* = object
    onFrameDrawn*: FrameDrawnCallback
    onReconstruct*: ReconstructCallback
    onResize*: ResizeCallback
    onProcessFault*: ProcessFaultCallback
    onPageTitleChange*: PageTitleCallback
    onSetCursorShape*: CursorShapeCallback
    onAlert*: AlertCallback
    onNavigationUpdate*: NavigationUpdateCallback

  WebViewObj = object
    master*: Master
    opts*: WebViewOpts
    callbacks*: WebViewCallbacks

    bufferFd*: int32
    bufferStride*: uint32

    pollingFd*: int32

  WebView* = ref WebViewObj

{.push inline, raises: [].}
func `onFrameDrawn=`*(view: WebView, cb: FrameDrawnCallback) =
  view.callbacks.onFrameDrawn = cb

func `onReconstruct=`*(view: WebView, cb: ReconstructCallback) =
  view.callbacks.onReconstruct = cb

func `onResize=`*(view: WebView, cb: ResizeCallback) =
  view.callbacks.onResize = cb

func `onProcessFault=`*(view: WebView, cb: ProcessFaultCallback) =
  view.callbacks.onProcessFault = cb

func `onPageTitleChange=`*(view: WebView, cb: PageTitleCallback) =
  view.callbacks.onPageTitleChange = cb

func `onSetCursorShape=`*(view: WebView, cb: CursorShapeCallback) =
  view.callbacks.onSetCursorShape = cb

func `onAlert=`*(view: WebView, cb: AlertCallback) =
  view.callbacks.onAlert = cb

func `onNavigationUpdate=`*(view: WebView, cb: NavigationUpdateCallback) =
  view.callbacks.onNavigationUpdate = cb

{.pop.}

converter u32*(id: TabID): uint32 =
  cast[uint32](id)

proc `=destroy`*(view: WebViewObj) =
  debug "~WebView()"
