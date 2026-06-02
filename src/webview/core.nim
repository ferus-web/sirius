## Core routines for WebView
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, streams, strformat, strutils, sequtils, tables]
import ./[hit_testing, types]
import pkg/[chronicles, chroma, pixie, results, shakar, url, vmath, xkb], pkg/surfer/app
import
  components/gfx/[core, init, font_loader],
  components/html/[dom, dom_utils],
  components/style/[parser, matching],
  components/layout/[flow, node_builder, output_manager, types],
  components/os/[assets, fonts, threads],
  components/net/core

logScope:
  topics = "webview/core"

proc initWebView*(): WebView =
  debug "Initialize WebView"
  setThreadName("WebView")

  let webview = WebView(
    app: newApp(title = "Sirius", appId = "xyz.xtrayambak.sirius"),
    outputManager: OutputManager(),
    imageCache: newTable[string, pixie.Image](),
  )
  webview.app.initialize()
  webview.app.createWindow(ivec2(1024, 768), Renderer.GLES)
  webview.renderCtx = newRenderingContext()

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

  webview.net = newNetworkClient(
    userAgent =
      "Mozilla/5.0 Sirius (+https://github.com/ferus-web/sirius; Wayland; Linux x86_64; rv: 0.1.0)"
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
    # FIXME: Use `baseUrl = some(view.target)`. There is a bug in nim-url that seems to make the first character of `segment` disappear when we do that. Fix it and do this.
  if *absoluteByDefault:
    # If the segment is absolute on its own, return its parsed representation.
    return ok(&absoluteByDefault)

  # Otherwise, if the parsing error was not related to relativity, return nothing.
  # The segment is likely malformed.
  if absoluteByDefault.error() notin
      {ParseError.RelativeUrlWithoutBase, ParseError.MissingSchemeNonRelativeUrl}:
    error "Cannot resolve URL segment",
      segment = segment, fault = absoluteByDefault.error()
    return absoluteByDefault

  # Let fixedBuffer be a String. Now, perform the following steps on it.
  let
    baseScheme = view.target.scheme
    baseHost = view.target.host

  var fixedBuffer = newStringOfCap(segment.len + baseScheme.len + 3 + baseHost.len + 1)

  # 1. Append the WebView's base URL's scheme to it, along with "://"
  fixedBuffer &= baseScheme
  fixedBuffer &= "://"

  # 2. Append the WebView's base URL's host to it.
  fixedBuffer &= baseHost

  # 3. If the segment does not begin with '/', append '/' to fixedBuffer.
  if not segment.startsWith('/'):
    fixedBuffer &= '/'

  # 4. Append the segment to fixedBuffer.
  fixedBuffer &= segment

  # 5. Return the result of URL parsing performed on fixedBuffer.
  tryParseURL(ensureMove(fixedBuffer))

proc loadHTMLStream(view: WebView, stream: Stream) =
  stream.setPosition(0)

  let userAgent = &view.assetProvider.openAssetStream("user-agent.css")

  view.stylesheet = parseStylesheet(newParser(newParserInput(userAgent.readAll())))
  view.dom = parseHTML(
    stream,
    callbacks = MiniDOMBuilderCallbacks(
      insertStyle: proc(text: string) =
        # HACK: yeah... we don't do stuff like this.
        view.style &= text,
      finishStyle: proc() =
        echo view.style
        view.stylesheet &= parseStylesheet(newParser(newParserInput(move(view.style)))),
      handleLinkElement: proc(element: dom.Element, factory: dom.MAtomFactory) =
        let
          rel = element.getAttr(factory, "rel")
          href = element.getAttr(factory, "href")

        if (!rel or !href) or &rel != "stylesheet":
          return

        let relURL = view.resolveURLSegment(&href)

        info "Found external stylesheet", href = relURL
        # FIXME: This blocks
        let (resp, err) = view.net.getStream(&relURL)
        assert err.kind == TransportErrorKind.None
        resp.body.stream.setPosition(0)

        let style = resp.body.stream.readAll()
        view.style &= style,
      fetchImageResource: proc(
          element: dom.HTMLImageElement, factory: dom.MAtomFactory
      ) =
        let
          srcRaw = element.getAttr(factory, "src")
          src = view.resolveURLSegment(&srcRaw)
          (resp, err) = view.net.getStream(&src)

        element.src = srcRaw

        if err.kind != TransportErrorKind.None:
          error "Failed to fetch image", src = src, err = err.kind
          return

        resp.body.stream.setPosition(0)
        debug "Fetched image", src = &src, size = resp.body.stream.data.len
        try:
          view.imageCache[&srcRaw] = decodeImage(resp.body.stream.readAll())
        except pixie.PixieError as exc:
          error "Failed to decode image, it will not be shown!",
            err = exc.msg, src = &src, size = resp.body.stream.data.len
      ,
    ),
  )
  userAgent.close()

  let title = getDocumentTitle(view.dom)
  if *title:
    view.app.setTitle(&"{&title} — Sirius")

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
  let (resp, err) =
    view.net.getStream(url, timeoutMs = 60000) # TODO: Timeout should be customizable

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
    loadUrl(view, view.target)
  of SchemeType.File:
    loadFile(view, view.target.host & view.target.pathname)

proc handleFocusedDomElement(
    view: WebView, element: dom.Element, clicked: bool = false
): bool {.discardable.} =
  if element.childList.len > 0 and
      (let href = getAttr(element, view.dom.factory, "href"); *href):
    view.app.setCursorShape(Shape.Pointer)
    if clicked:
      if (let standalone = tryParseURL(&href); *standalone):
        view.target = &standalone
        loadURL(view, view.target)
        return true

      echo view.target.scheme & view.target.host & &href
      view.target = parseURL(view.target.scheme & "://" & view.target.host & &href)
        # HACK: This is bad.
      loadURL(view, view.target)

    return true

  for child in element.childList:
    if not (child of dom.Element):
      continue

    if handleFocusedDomElement(view, Element(child), clicked = clicked):
      break

proc handleFocusedElement(view: WebView, clicked: bool = false) =
  if !view.focusedElement:
    return

  let elem = &view.focusedElement
  if elem.domNode of dom.Element:
    handleFocusedDomElement(view, Element(elem.domNode), clicked = clicked)

proc loop*(view: WebView): int =
  info "Entering main loop"

  while not view.app.closureRequested:
    let eventOpt = view.app.flushQueue()
    if !eventOpt:
      continue

    let event = &eventOpt
    case event.kind
    of EventKind.RedrawRequested:
      view.renderCtx.drawFrame()
      view.app.queueRedraw()
    of EventKind.WindowResized:
      view.renderCtx.resize(vec2(event.windowSize))
      view.renderCtx.tree = view.tree.clone()
      view.renderCtx.tree.computeLayout(
        vec2(0, 0), float32(event.windowSize.x), view.outputManager
      )
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
    of EventKind.CursorMove:
      view.cursor = event.cursor.pos
      let lastFocused = view.focusedElement
      view.focusedElement = hitTest(view, view.renderCtx.tree, view.cursor)

      handleFocusedElement(view, clicked = false)
    of EventKind.CursorFocusObtained:
      view.app.setCursorShape(Shape.Default)
    of EventKind.CursorClick:
      handleFocusedElement(view, clicked = true)
    else:
      discard # debug "Unhandled surfer event", kind = event.kind

  info "Exiting main loop"
  return 0
