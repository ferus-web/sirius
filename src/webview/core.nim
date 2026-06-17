## Core routines for WebView
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, streams, strformat, strutils, sequtils, tables]
import ./[hit_testing, resource_loader, types]
import pkg/[chronicles, chroma, pixie, results, shakar, url, vmath, xkb], pkg/surfer/app
import
  components/gfx/[core, init, font_loader],
  components/dom/[dom, tags],
  components/html/[parser, dom_utils, data_parser],
  components/style/[parser, matching],
  components/layout/[flow, node_builder, output_manager, types],
  components/os/[assets, fonts, threads],
  components/net/core,
  components/scripting/types,
  components/js/grammar/prelude,
  components/js/runtime/prelude

logScope:
  topics = "webview/core"

proc waitForRendererInit(webview: WebView) =
  # A tiny hack because some compositors are incredibly strict about buffer attach timings.
  # Here, we wait till Surfer signals that the renderer context is ready.

  while true:
    let event = &webview.app.flushQueue()
    if event.kind == EventKind.WindowResized:
      break # The OpenGL context is (probably) ready.
    elif event.kind == EventKind.RedrawRequested:
      # We should respond to these with a requeue.
      webview.app.queueRedraw()

proc initWebView*(opts: WebViewOpts): WebView =
  debug "Initialize WebView"
  setThreadName("WebView")

  let webview = WebView(
    app: newApp(title = "Sirius", appId = "xyz.xtrayambak.sirius"),
    outputManager: OutputManager(),
    imageCache: newTable[string, pixie.Image](),
    opts: opts,
    failedPlaceholderImage: newImage(64, 64),
  )
  webview.failedPlaceholderImage.fill(rgb(255, 0, 0))

  webview.app.initialize()
  webview.app.createWindow(ivec2(1024, 768), Renderer.GLES)
  waitForRendererInit(webview)

  webview.renderCtx = newRenderingContext(vec2(webview.app.windowSize))

  webview.fontProvider = initFontProvider(getLoaderImplementation(webview.renderCtx.vg))
  webview.assetProvider = initAssetProvider(
    AssetProviderImplementation(
      openAssetStream: proc(name: string): Option[FileStream] =
        # TODO: Proper asset providers (debug/release)
        let stream = newFileStream(&"assets/{name}")
        if stream == nil:
          warn "Cannot open asset stream", name = name
          return none(FileStream)

        debug "Opened asset stream", name = name
        some(stream)
    )
  )

  webview.renderCtx.outputManager = webview.outputManager
  webview.renderCtx.fontProvider = webview.fontProvider

  webview.loader = newResourceLoader(
    newNetworkClient(
      userAgent =
        "Mozilla/5.0 Sirius (+https://github.com/ferus-web/sirius; Wayland; Linux x86_64; rv: 0.1.0)"
    )
  )

  webview

proc getDocumentTitle(doc: dom.Document): Option[string] =
  proc walk(node: dom.Node): tuple[canContinue: bool, title: Option[string]] =
    if node of dom.Element and Element(node).tagType == TAG_TITLE:
      for child in node.childList:
        if child of dom.Text:
          return (canContinue: false, title: some(Text(child).data))

      return (canContinue: false, title: none(string)) # We must end the search anyways.

    for child in node.childList:
      let res = walk(child)
      if *res.title:
        return res
      elif not res.canContinue:
        return res

    (canContinue: true, title: none(string))

  walk(doc).title

proc resolveURLSegment*(
    view: WebView, segment: string
): Result[url.URL, url.ParseError] =
  ## Given a portion of the URL (e.g `/style.css`, `index.html`, etc.) or a full,
  ## absolute URL (e.g `https://foobar.lol/style.css`), resolve a full qualified URL.
  ##
  ## If the segment is not absolute, the view's base URL's scheme and host will be prefixed to the segment.
  # NOTE: I have zero clue if this is guaranteed to work everywhere. The below algorithm
  #       is simply based on my observations on what different sites had.

  let absoluteByDefault = tryParseURL(segment)
  if *absoluteByDefault:
    # If the segment is absolute on its own, return its parsed representation.
    return ok(&absoluteByDefault)

  # Otherwise, if the parsing error was not related to relativity, return nothing.
  # The segment is likely malformed.
  if absoluteByDefault.error() notin {
    url.ParseError.RelativeUrlWithoutBase, url.ParseError.MissingSchemeNonRelativeUrl
  }:
    error "Cannot resolve URL segment",
      segment = segment, fault = absoluteByDefault.error()
    return absoluteByDefault

  # Let fixedBuffer be a String. Now, perform the following steps on it.
  let
    baseScheme = view.target.scheme
    baseHost = view.target.host
    basePath = view.target.pathname

  var fixedBuffer =
    newStringOfCap(segment.len + baseScheme.len + 3 + baseHost.len + 1 + basePath.len)

  # 1. Append the WebView's base URL's scheme to it, along with "://"
  fixedBuffer &= baseScheme
  fixedBuffer &= "://"

  # 2. Append the WebView's base URL's host to it.
  fixedBuffer &= baseHost

  # 3. If the segment does not begin with '/', append '/', along with the base URL's path, to fixedBuffer.
  if not segment.startsWith('/'):
    fixedBuffer &= '/'
    fixedBuffer &= basePath

  # 4. Append the segment to fixedBuffer.
  fixedBuffer &= segment

  # 5. Return the result of URL parsing performed on fixedBuffer.
  tryParseURL(ensureMove(fixedBuffer))

proc reflow(view: WebView) =
  let htmlElem = view.dom.childList.filterIt(
    it of dom.Element and tagType(Element(it)) == TAG_HTML
  )[0] # HACK: This is stupid. Do it properly.

  view.styleMap = resolveStyling(htmlElem, view.dom.factory, view.stylesheet)
  view.tree =
    buildLayoutTree(htmlElem, view.styleMap, view.fontProvider, view.imageCache)
  propagateStyles(view.tree, view.styleMap, view.fontProvider)

  view.renderCtx.tree = view.tree.clone()
  view.renderCtx.tree.computeLayout(
    vec2(0, 0), float32(view.app.windowSize.x), view.outputManager
  )

proc insertStyle(view: WebView, text: string) =
  # HACK: yeah... we don't do stuff like this.
  view.style &= text

proc finishStyle(view: WebView) =
  if view.opts.disableStyling:
    warn "Styling is explicitly disabled. All styles will be derived from the user agent."
    return

  view.stylesheet &= parseStylesheet(newParser(newParserInput(move(view.style))))

proc handleHTMLLinkElement(
    view: WebView, element: dom.Element, factory: dom.MAtomFactory
) =
  let
    rel = element.getAttr(factory, "rel")
    href = element.getAttr(factory, "href")

  if (!rel or !href) or &rel != "stylesheet":
    return

  let relURL = view.resolveURLSegment(&href)

  info "Found external stylesheet", href = relURL
  discard view.loader.getAsyncStream(
    &relURL,
    finalize = proc(resp: Response, err: TransportError) =
      if resp.code == 200:
        let style = resp.body.stream.readAll()
        if not view.opts.disableExternalStylesheets:
          view.stylesheet &= parseStylesheet(newParser(newParserInput(style)))
          view.reflow()
    ,
  )

proc fetchHTMLImageResource(
    view: WebView, element: tags.HTMLImageElement, factory: dom.MAtomFactory
) =
  if view.opts.disableImageLoading:
    return

  let
    srcRaw = element.getAttr(factory, "src")
    src = view.resolveURLSegment(&srcRaw)

  element.src = srcRaw
  element.width = element.getUintAttr(factory, "width")
  element.height = element.getUintAttr(factory, "height")

  let dataUrlOpt = parseDataURL(&srcRaw)

  if !dataUrlOpt:
    discard view.loader.getAsyncStream(
      &src,
      finalize = proc(resp: Response, err: TransportError) =
        if err.kind != TransportErrorKind.None:
          error "Failed to fetch image", src = src, err = err.kind
          return

        debug "Fetched image", src = &src, size = resp.body.stream.data.len
        try:
          view.imageCache[&srcRaw] = decodeImage(resp.body.stream.readAll())
        except pixie.PixieError as exc:
          error "Failed to decode image, it will not be shown!",
            err = exc.msg, src = &src, size = resp.body.stream.data.len
          view.imageCache[&srcRaw] = view.failedPlaceholderImage

        view.reflow(),
    )
  else:
    let dataUrl = &dataUrlOpt

    try:
      let decodedData = dataUrl.decodeBase64()

      if *decodedData:
        view.imageCache[&srcRaw] = decodeImage(&decodedData)
      else:
        warn "Image element has data URL, but its content could not be decoded as base64."
    except pixie.PixieError as exc:
      error "Failed to decode image, it will not be shown!",
        err = exc.msg, src = &srcRaw
      view.imageCache[&srcRaw] = view.failedPlaceholderImage

proc executeScript(view: WebView, element: tags.HTMLScriptElement) =
  var codeBuffer: string # TODO: Prealloc somehow?
  for child in element.childList:
    if child of dom.Text:
      codeBuffer &= Text(child).data

  let parser = newParser(ensureMove(codeBuffer))
  element.script = Script(ast: parser.parse(), baseURL: view.target)
  element.script.rt = newRuntime(
    file = "<inline-script>", # TODO: We can probably use more descriptive names?
    ast = element.script.ast,
    opts = InterpreterOpts(
      test262: false,
      repl: false,
      dumpBytecode: false,
      insertDebugHooks: true,
      codegen: CodegenOpts(
        elideLoops: false,
        loopAllocationEliminator: false,
        aggressivelyFreeRetvals: false,
        deadCodeElimination: false,
        jitCompiler: false,
      ),
      jit: JITOpts(),
    ),
  )
  element.script.rt.run()

proc loadHTMLStream(view: WebView, stream: Stream) =
  let userAgent = &view.assetProvider.openAssetStream("user-agent.css")

  view.stylesheet = parseStylesheet(newParser(newParserInput(userAgent.readAll())))
  view.dom = parseHTML(
    stream,
    callbacks = MiniDOMBuilderCallbacks(
      insertStyle: proc(text: string) =
        view.insertStyle(text),
      finishStyle: proc() =
        view.finishStyle(),
      handleLinkElement: proc(element: dom.Element, factory: dom.MAtomFactory) =
        view.handleHTMLLinkElement(element, factory),
      fetchImageResource: proc(
          element: tags.HTMLImageElement, factory: dom.MAtomFactory
      ) =
        view.fetchHTMLImageResource(element, factory),
      executeScript: proc(element: tags.HTMLScriptElement) =
        view.executeScript(element),
    ),
  )
  userAgent.close()

  let title = getDocumentTitle(view.dom)
  if *title:
    view.app.setTitle(&"{&title} — Sirius")

  view.reflow()
  view.renderCtx.viewerPosition = vec2(0, 0)

  view.app.setCursorShape(Shape.Default)

  stream.close()

proc loadFile(view: WebView, path: string) =
  loadHTMLStream(view, openFileStream(path))

proc showTransportErrorPage(view: WebView, url: URL, err: TransportError) =
  let errorTemplateFile = &view.assetProvider.openAssetStream(
    case err.kind
    of TransportErrorKind.DNS: "resources/dns-error.html"
    of TransportErrorKind.TLS: "resources/tls-error.html"
    else: "resources/network-error.html"
  )
  var errorTemplate =
    errorTemplateFile.readAll() %
    [err.message, &"TransportErrorKind::{err.kind}", &url.hostname()]
  errorTemplateFile.close()

  loadHTMLStream(view, newStringStream(ensureMove(errorTemplate)))

proc loadUrl(view: WebView, url: URL) =
  echo "loadURL " & $url
  view.target = url
  view.app.setCursorShape(Shape.Wait)

  let (resp, err) = view.loader.net.getStream(url, timeoutMs = 60000)
    # TODO: Timeout should be customizable

  if err.kind == TransportErrorKind.None:
    loadHTMLStream(view, resp.body.stream)
  else:
    error "An error occurred while fetching the requested content",
      message = err.message
    showTransportErrorPage(view, url, err)

proc loadPage*(view: WebView, target: string) =
  view.target = parseURL(target)
  debug "Load page", target = view.target, scheme = view.target.scheme

  case getSchemeType(view.target)
  of SchemeType.Ws, SchemeType.Ftp, SchemeType.Wss, SchemeType.NotSpecial:
    assert off, "Not supported"
  of SchemeType.Http, SchemeType.Https:
    loadURL(view, view.target)
  of SchemeType.File:
    loadFile(view, view.target.host & view.target.pathname)

proc applyCursorState(view: WebView, layoutNode: LayoutNode) =
  if !layoutNode.cursor:
    return

  # Source: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/cursor
  let cursorMap = toTable {
    "default": Shape.Default,
    "pointer": Shape.Pointer,
    "context-menu": Shape.ContextMenu,
    "help": Shape.Help,
    "progress": Shape.Progress,
    "wait": Shape.Wait,
    "cell": Shape.Cell,
    "crosshair": Shape.Crosshair,
    "text": Shape.Text,
    "vertical-text": Shape.VerticalText,
    "alias": Shape.Alias,
    "copy": Shape.Copy,
    "move": Shape.Move,
    "no-drop": Shape.NoDrop,
    "not-allowed": Shape.NotAllowed,
    "grab": Shape.Grab,
    "grabbing": Shape.Grabbing,
    "all-scroll": Shape.AllScroll,
    "col-resize": Shape.ColResize,
    "row-resize": Shape.RowResize,
    "n-resize": Shape.NResize,
    "e-resize": Shape.EResize,
    "s-resize": Shape.SResize,
    "w-resize": Shape.WResize,
    "ne-resize": Shape.NEResize,
    "nw-resize": Shape.NWResize,
    "se-resize": Shape.SEResize,
    "sw-resize": Shape.SWResize,
    "ew-resize": Shape.EWResize,
    "ns-resize": Shape.NSResize,
    "nesw-resize": Shape.NESWResize,
    "nwse-resize": Shape.NWSEResize,
    "zoom-in": Shape.ZoomIn,
    "zoom-out": Shape.ZoomOut,
  }
  let cursor = &layoutNode.cursor

  if cursor in cursorMap:
    view.app.setCursorShape(cursorMap[cursor])

proc handleFocusedDomElement(
    view: WebView, layoutNode: LayoutNode, element: dom.Element, clicked: bool = false
): bool {.discardable.} =
  applyCursorState(view, layoutNode)

  if clicked and element of tags.HTMLAnchorElement:
    let anchorElement = HTMLAnchorElement(element)
    if *anchorElement.href:
      # TODO: The styling engine needs to support :not so that if an anchor element
      # doesn't have a href, it should _NOT_ appear as clickable due to `cursor: pointer`
      # in Sirius' UA stylesheet globally applied to all anchors.
      loadURL(view, &view.resolveURLSegment(&anchorElement.href))

    return true

proc handleFocusedElement(view: WebView, clicked: bool = false) =
  if !view.focusedElement:
    view.app.setCursorShape(Shape.Default)
    return

  let elem = &view.focusedElement
  if elem.domNode of dom.Element:
    handleFocusedDomElement(view, elem, Element(elem.domNode), clicked = clicked)

proc handleWindowResize(view: WebView, viewportSize: IVec2) =
  view.renderCtx.resize(vec2(viewportSize))
  view.renderCtx.tree = view.tree.clone()
  view.renderCtx.tree.computeLayout(
    vec2(0, 0), float32(viewportSize.x), view.outputManager
  )

proc loop*(view: WebView): int =
  info "Entering main loop"

  while not view.app.closureRequested:
    view.loader.poll()

    let eventOpt = view.app.flushQueue()
    if !eventOpt:
      continue

    let event = &eventOpt
    case event.kind
    of EventKind.RedrawRequested:
      view.renderCtx.drawFrame()
      view.app.queueRedraw()
    of EventKind.WindowResized:
      handleWindowResize(view, event.windowSize)
      # print view.renderCtx.tree
    of EventKind.KeyPressed, EventKind.KeyRepeated:
      let keysym = view.app.xkbState.getOneSym(event.key.code + 8)
      if keysym == XKB_Key_Down or keysym == XKB_KEY_Page_Down:
        view.renderCtx.viewerPosition.y -= 5
      elif keysym == XKB_Key_Up or keysym == XKB_KEY_Page_Up:
        view.renderCtx.viewerPosition.y += 5
      elif keysym == XKB_Key_Left:
        view.renderCtx.viewerPosition.x += 5
      elif keysym == XKB_Key_Right:
        view.renderCtx.viewerPosition.x -= 5
      elif keysym == XKB_Key_Tab:
        view.renderCtx.paintDebugBounds = not view.renderCtx.paintDebugBounds
    of EventKind.CursorMove:
      view.cursor = event.cursor.pos
      let lastFocused = view.focusedElement
      view.focusedElement = hitTest(view, view.renderCtx.tree, view.cursor)

      handleFocusedElement(view, clicked = false)
    of EventKind.CursorFocusObtained:
      view.app.setCursorShape(Shape.Default)
    of EventKind.CursorScroll:
      view.renderCtx.scrollVelocity = event.cursor.scroll * 0.25'f32
    of EventKind.CursorClick:
      if event.cursor.state == ButtonState.Released:
        handleFocusedElement(view, clicked = true)
    else:
      discard # debug "Unhandled surfer event", kind = event.kind

  info "Exiting main loop"
  return 0
