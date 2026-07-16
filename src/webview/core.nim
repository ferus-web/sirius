## Core routines for WebView
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[monotimes, options, streams, strformat, strutils, sequtils, tables, unicode]
import ./[cookie_jar, hit_testing, resource_loader, types]
import pkg/[chronicles, chroma, pixie, results, shakar, url, vmath, xkb], pkg/surfer/app
import
  components/aux/[pretty, stream_utils],
  components/gfx/[core, init, painter, font_loader],
  components/dom/[dom, tags],
  components/html/[parser, dom_utils, data_parser, meta],
  components/style/[parser, matching],
  components/layout/[flow, node_builder, output_manager, types],
  components/os/[assets, fonts, threads],
  components/net/[cookie_parser, core, mime],
  components/js/grammar/prelude,
  components/js/runtime/[arguments, bridge, common, construction, wrapping, types],
  components/js/runtime/vm/heap/manager,
  components/js/runtime/compiler/base,
  components/scripting/[executor, types],
  components/scripting/url as jsurl

when hasJITSupport:
  import components/js/internal/assembler/amd64

logScope:
  topics = "webview/core"

proc waitForRendererInit(webview: WebView) =
  # A tiny hack because some compositors are incredibly strict about buffer attach timings.
  # Here, we wait till Surfer signals that the renderer context is ready.

  while true:
    let event = &webview.app.flushQueue()
    if event.kind == EventKind.WindowResized:
      webview.renderCtx = newRenderingContext(webview.app, vec2(event.windowSize))
      webview.renderCtx.drawTree()
      break # The OpenGL context is (probably) ready.
    elif event.kind == EventKind.RedrawRequested:
      # We should respond to these with a requeue.
      webview.app.queueRedraw()

proc loadUrl(view: WebView, url: URL)

proc initCoreScript(view: WebView) =
  proc registerCoreBindings(view: WebView) =
    view.coreScript.script.rt.defineFn(
      "loadURL",
      proc() =
        {.cast(gcsafe).}:
          # I'll take my ACM Turing award tomorrow, thank you
          view.loadURL(
            view.coreScript.script.rt.toNativeURL(
              &view.coreScript.script.rt.argument(1, required = true)
            )
          ),
    )

  let stream = &view.assetProvider.openAssetStream("scripts/core.js")

  view.coreScript = HTMLScriptElement(
    script: Script(
      baseURL: parseURL("file://assets/scripts/core.js"),
      document: view.dom,
      rt: newRuntime(file = "sirius::core", ast = nil),
    )
  )
  view.registerCoreBindings()
  view.coreScript.executeScript(readAll(stream))
  stream.close()

proc initWebView*(opts: WebViewOpts): WebView =
  debug "Initialize WebView"
  setThreadName("WebView")

  let webview = WebView(
    app: newApp(title = "Sirius", appId = "xyz.xtrayambak.sirius"),
    outputManager: OutputManager(),
    imageCache: newTable[string, pixie.Image](),
    opts: opts,
    failedPlaceholderImage: newImage(64, 64),
    cookieJar: loadCookieJar(),
  )
  webview.failedPlaceholderImage.fill(rgb(255, 0, 0))

  webview.app.initialize()
  webview.app.createWindow(ivec2(1024, 768), Renderer.Vulkan)
  waitForRendererInit(webview)

  webview.fontProvider = initFontProvider(getLoaderImplementation())
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

  initCoreScript(webview)

  webview.renderCtx.outputManager = webview.outputManager
  webview.renderCtx.fontProvider = webview.fontProvider

  webview.loader = newResourceLoader(
    newNetworkClient(
      userAgent =
        "Mozilla/5.0 Sirius (+https://git.xtrayambak.xyz/ferus-web/sirius; Wayland; Linux x86_64; rv: 0.1.0)"
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
  tryParseURL(segment, some(view.target))

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
    vec2(0, 0), float32(view.app.windowSize.x), view.outputManager, view.fontProvider
  )

  view.renderCtx.imageCache = view.imageCache
  view.renderCtx.invalidate()

proc insertStyle(view: WebView, text: string) =
  # HACK: yeah... we don't do stuff like this.
  view.style &= text

proc finishStyle(view: WebView) =
  if view.opts.disableStyling:
    warn "Styling is explicitly disabled. All styles will be derived from the user agent."
    return

  view.stylesheet &= parseStylesheet(newParser(newParserInput(move(view.style))))

proc handleHTMLLinkElement(
    view: WebView, element: dom.Element, factory: dom.AtomFactory
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
    view: WebView, element: tags.HTMLImageElement, factory: dom.AtomFactory
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
          view.imageCache[&srcRaw] = view.failedPlaceholderImage
          view.renderCtx.reuploadImage(&srcRaw)
          view.reflow()
          return

        debug "Fetched image", src = &src, size = resp.body.stream.data.len
        try:
          view.imageCache[&srcRaw] = decodeImage(resp.body.stream.readAll())
        except pixie.PixieError as exc:
          error "Failed to decode image, it will not be shown!",
            err = exc.msg, src = &src, size = resp.body.stream.data.len
          view.imageCache[&srcRaw] = view.failedPlaceholderImage

        view.renderCtx.reuploadImage(&srcRaw)
        view.reflow(),
    )
  else:
    let dataUrl = &dataUrlOpt

    try:
      let decodedData = dataUrl.decodeBase64()

      if *decodedData:
        view.imageCache[&srcRaw] = decodeImage(&decodedData)
        view.renderCtx.reuploadImage(&srcRaw)
        element.document.edited = true
        # view.reflow()
      else:
        warn "Image element has data URL, but its content could not be decoded as base64."
    except pixie.PixieError as exc:
      error "Failed to decode image, it will not be shown!",
        err = exc.msg, src = &srcRaw
      view.imageCache[&srcRaw] = view.failedPlaceholderImage

proc executeScript(
    view: WebView, element: tags.HTMLScriptElement, document: dom.Document
) =
  if view.opts.disableScripting:
    return

  var codeBuffer: string # TODO: Prealloc somehow?
  for child in element.childList:
    if child of dom.Text:
      codeBuffer &= Text(child).data

  element.script = Script(baseURL: view.target, document: document)
  executeScript(element, ensureMove(codeBuffer))

  view.scripts &= element

proc handleHTMLMetaElement(view: WebView, element: HTMLMetaElement) =
  if !element.httpEquiv:
    return # TODO: We should probably handle other metadata tags too..

  let httpEquiv = &element.httpEquiv
  case httpEquiv
  of HTTPEquiv.Refresh:
    let dataOpt = parseRefreshData(&element.content)
    if !dataOpt:
      warn "Cannot handle Refresh metadata, failed to parse metadata content",
        message = dataOpt.error()
      return

    let data = &dataOpt
    view.coreScript.script.rt.callNoRetval(
      &view.coreScript.script.rt.get("handleRefreshMeta"),
      @[
        view.coreScript.script.rt.wrap(data.time),
        view.coreScript.script.rt.transposeUrlToObject(data.urlRecord, $data.urlRecord),
      ],
    )
  else:
    warn "Ignoring unhandled http-equiv for <meta> tag", value = httpEquiv

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
      handleLinkElement: proc(element: dom.Element, factory: dom.AtomFactory) =
        view.handleHTMLLinkElement(element, factory),
      fetchImageResource: proc(
          element: tags.HTMLImageElement, factory: dom.AtomFactory
      ) =
        view.fetchHTMLImageResource(element, factory),
      executeScript: proc(element: tags.HTMLScriptElement, document: dom.Document) =
        view.executeScript(element, document),
      handleMetaElement: proc(element: tags.HTMLMetaElement) =
        view.handleHTMLMetaElement(element),
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

proc cleanup(view: WebView) =
  debug "Cleaning up resources from previous page"
  if view.dom == nil:
    debug "Nothing to cleanup."
    return

  # TODO: Ideally, we should handle this in Bali alongside freeing the JIT buffers
  for scriptElement in view.scripts:
    # Free memory used by JIT assemblers
    when hasJITSupport and defined(amd64):
      scriptElement.script.rt.vm.baseline.s.release()
      scriptElement.script.rt.vm.midtier.s.release()

  view.realm.heap.release()
  view.scripts.reset()

proc loadImageStream(view: WebView, resp: Response) =
  let imageViewerTemplate =
    &view.assetProvider.openAssetStream("resources/image-viewer.html")
  let viewerTemplate =
    imageViewerTemplate.readAll() %
    [(&resp.url).pathname.strip(chars = {'/'}), resp.body.stream.encodeBase64()]

  imageViewerTemplate.close()

  view.loadHTMLStream(newStringStream(viewerTemplate))

proc parseAndHandleCookie(view: WebView, cookieStr: string) =
  let parsed = parseCookie(view.target, cookieStr)
  if !parsed:
    warn "Failed to parse cookie! Is it malformed?", buffer = cookieStr
    return

  view.cookieJar.insert(&parsed)

proc handleResponseHeaders(view: WebView, headers: HttpHeaders) =
  for hdr in headers:
    if cmpIgnoreCase(hdr.name, "set-cookie") == 0:
      view.parseAndHandleCookie(hdr.value)

proc loadStream(view: WebView, resp: Response) =
  view.handleResponseHeaders(resp.headers)

  let contentType = resp.contentType()

  if !contentType:
    # If there's no Content-Type, we're probably best off assuming this is HTML.
    view.loadHTMLStream(resp.body.stream)
    return

  case &contentType
  of MimeType.HTML:
    view.loadHTMLStream(resp.body.stream)
    return
  of MimeType.JPEG, MimeType.PNG, MimeType.WebP:
    view.loadImageStream(resp)
  else:
    warn "Unhandled content type", typ = &contentType

proc loadUrl(view: WebView, url: URL) =
  info "Loading page", dest = url

  view.cleanup()

  view.target = url
  view.realm = newRealm()
  # view.app.setCursorShape(Shape.Progress)

  view.dom = Document()
  discard view.loader.getAsyncStream(
    url = url,
    timeoutMs = 60000,
    finalize = proc(resp: Response, err: TransportError) =
      if err.kind == TransportErrorKind.None:
        view.loadStream(resp)
      else:
        error "An error occurred while fetching the requested content",
          message = err.message
        view.showTransportErrorPage(url, err),
  )

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
    let shape = cursorMap[cursor]

    if shape == Shape.Default and view.progress:
      view.app.setCursorShape(Shape.Progress)
    else:
      view.app.setCursorShape(shape)

proc handleFocusedDomElement(
    view: WebView, layoutNode: LayoutNode, element: dom.Element, clicked: bool = false
): bool {.discardable.} =
  applyCursorState(view, layoutNode)

  if clicked:
    if element of tags.HTMLAnchorElement:
      let anchorElement = HTMLAnchorElement(element)
      if *anchorElement.href:
        # TODO: The styling engine needs to support :not so that if an anchor element
        # doesn't have a href, it should _NOT_ appear as clickable due to `cursor: pointer`
        # in Sirius' UA stylesheet globally applied to all anchors.
        loadURL(view, &view.resolveURLSegment(&anchorElement.href))

    view.keyboardFocusedElement = some(element)
    return true

proc handleFocusedElement(view: WebView, clicked: bool = false) =
  if !view.focusedElement:
    view.app.setCursorShape(if view.progress: Shape.Progress else: Shape.Default)
    return

  let elem = &view.focusedElement
  if elem.domNode of dom.Element:
    handleFocusedDomElement(view, elem, Element(elem.domNode), clicked = clicked)

proc handleWindowResize(view: WebView, viewportSize: IVec2) =
  view.renderCtx.resize(vec2(viewportSize))
  view.reflow()

proc executeOneMacrotask(view: WebView) =
  let currTime = getMonoTime()
  if view.coreScript.script.rt.macrotaskQueue.len > 0 and (
    let front = view.coreScript.script.rt.macrotaskQueue.peekFirst().addr
    front.deadline <= currTime
  ):
    view.coreScript.script.rt.callNoRetval(front.callback)

    if not front.flags.contains(TaskFlag.Immortal):
      discard view.coreScript.script.rt.macrotaskQueue.popFirst()

  for scriptElem in view.scripts:
    if scriptElem.script.rt.macrotaskQueue.len > 0 and (
      let front = scriptElem.script.rt.macrotaskQueue.peekFirst().addr
      front.deadline <= currTime
    ):
      scriptElem.script.rt.callNoRetval(front.callback)
      front.deadline = currTime + front.delay

      if not front.flags.contains(TaskFlag.Immortal):
        discard scriptElem.script.rt.macrotaskQueue.popFirst()

proc poll*(view: WebView) =
  view.loader.poll()
  view.progress = view.loader.pendingAssets.len > 0 or view.loader.retryQueue.len > 0

  view.executeOneMacrotask()

proc handleKeyboardEvent(view: WebView, event: Event) =
  let keysym = view.app.xkbState.getOneSym(event.key.code + 8)
  if *view.keyboardFocusedElement:
    let element = &view.keyboardFocusedElement
    if element of HTMLInputElement:
      let inputElement = HTMLInputElement(element)
      if keysym == XKB_Key_Backspace:
        if inputElement.inputBuffer.len > 0:
          inputElement.inputBuffer =
            inputElement.inputBuffer[0 ..< inputElement.inputBuffer.len - 1]

          view.reflow()
        return

      inputElement.inputBuffer &= Rune(view.app.xkbState.getUtf32(event.key.code + 8))
      view.reflow()

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
    view.reflow()

proc loop*(view: WebView): int =
  info "Entering main loop"

  while not view.app.closureRequested:
    view.poll()

    let eventOpt = view.app.flushQueue()
    if !eventOpt:
      continue

    let event = &eventOpt
    case event.kind
    of EventKind.RedrawRequested:
      view.renderCtx.drawTree()

      if view.dom.edited:
        view.reflow()
        view.dom.edited = false
    of EventKind.WindowResized:
      handleWindowResize(view, event.windowSize)
      view.renderCtx.drawTree()
      # print view.renderCtx.tree
    of EventKind.KeyPressed, EventKind.KeyRepeated:
      handleKeyboardEvent(view, event)
    of EventKind.CursorMove:
      view.cursor = event.cursor.pos
      let lastFocused = view.focusedElement
      if view.renderCtx.tree != nil:
        view.focusedElement = hitTest(view, view.renderCtx.tree, view.cursor)

      handleFocusedElement(view, clicked = false)
    of EventKind.CursorScroll:
      view.renderCtx.scrollVelocity = event.cursor.scroll * 0.25'f32
    of EventKind.CursorClick:
      if event.cursor.state == ButtonState.Released:
        handleFocusedElement(view, clicked = true)
    else:
      discard # debug "Unhandled surfer event", kind = event.kind

  info "Exiting main loop"
  view.cookieJar.write()
  return 0
