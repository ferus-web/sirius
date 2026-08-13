## Routines for WebView's Renderer process
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import
  std/[
    algorithm, monotimes, options, streams, strformat, strutils, sequtils, tables,
    unicode, os, times,
  ]
import ./[branding, cookie_jar, hit_testing, resource_loader, types]
import
  pkg/[chronicles, chroma, pixie, results, shakar, url, vmath, xkb],
  pkg/figdraw/vulkan/vulkan_context
import
  components/aux/[pretty, stream_utils],
  components/gfx/[core, init, painter, font_loader],
  components/dom/[dom, tags],
  components/html/[parser, dom_utils, data_parser, meta],
  components/html/form/[owner, encoder, types],
  components/style/[parser, matching],
  components/layout/[flow, node_builder, output_manager, types],
  components/os/[assets, fonts, threads],
  components/net/[cookie, cookie_parser, core, mime],
  components/js/grammar/prelude,
  components/js/runtime/[arguments, bridge, common, construction, wrapping, types],
  components/js/runtime/vm/atom,
  components/js/runtime/vm/heap/manager,
  components/js/runtime/compiler/base,
  components/scripting/[executor, types],
  components/scripting/url as jsurl,
  components/synapse/[client, encoder, decoder, types, transport/socketpairs],
  components/synapse/descriptors/[renderer, master]

when hasJITSupport:
  import components/js/internal/assembler/amd64

logScope:
  topics = "webview/renderer"

proc loadUrl(view: WebRenderer, url: URL)

proc initCoreScript(view: WebRenderer) =
  proc registerCoreBindings(view: WebRenderer) =
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

proc initRenderer*(ipcChannel: int32): WebRenderer =
  debug "Initialize Renderer", channel = ipcChannel
  setThreadName("WebRenderer")

  when defined(siriusRendererAttachPeriod):
    let processId = getCurrentProcessId()
    for i in countDown(20, 1):
      echo &"#{i}: sudo gdb -p {processId}" # imagine using doas ;)
      sleep(1000)

  let webview = WebRenderer(
    outputManager: OutputManager(),
    client: initClient(ipcChannel),
    imageCache: newTable[string, pixie.Image](),
    failedPlaceholderImage: newImage(64, 64),
    cookieJar: loadCookieJar(),
    renderCtx: newRenderingContext(vec2(640, 480)),
  )

  webview.cookieJar.collect()
  webview.failedPlaceholderImage.fill(rgb(255, 0, 0))

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
    view: WebRenderer, segment: string
): Result[url.URL, url.ParseError] =
  ## Given a portion of the URL (e.g `/style.css`, `index.html`, etc.) or a full,
  ## absolute URL (e.g `https://foobar.lol/style.css`), resolve a full qualified URL.
  ##
  ## If the segment is not absolute, the view's base URL's scheme and host will be prefixed to the segment.
  tryParseURL(segment, some(view.target))

proc reflow(view: WebRenderer) =
  let htmlElemFiltered =
    view.dom.childList.filterIt(it of dom.Element and tagType(Element(it)) == TAG_HTML)
  if htmlElemFiltered.len < 1:
    # if the DOM is empty, don't attempt to reflow it
    return

  let htmlElem = htmlElemFiltered[0] # HACK: This is stupid. Do it properly.

  view.styleMap = resolveStyling(htmlElem, view.dom.factory, view.stylesheet)
  view.tree =
    buildLayoutTree(htmlElem, view.styleMap, view.fontProvider, view.imageCache)
  propagateStyles(view.tree, view.styleMap, view.fontProvider)

  view.renderCtx.tree = view.tree.clone()
  computeLayout(
    FlowContext(
      document: view.dom,
      availableWidth: float32(view.renderCtx.renderSize.x),
      outputManager: view.outputManager,
      fontProvider: view.fontProvider,
      parentExplicitHeight: none(float32),
    ),
    node = view.renderCtx.tree,
    parent = vec2(0, 0),
  )

  view.renderCtx.imageCache = view.imageCache
  view.renderCtx.invalidate()

proc insertStyle(view: WebRenderer, text: string) =
  # HACK: yeah... we don't do stuff like this.
  view.style &= text

proc finishStyle(view: WebRenderer) =
  if view.opts.disableStyling:
    warn "Styling is explicitly disabled. All styles will be derived from the user agent."
    return

  view.stylesheet &= parseStylesheet(newParser(newParserInput(move(view.style))))

proc handleHTMLLinkElement(
    view: WebRenderer, element: dom.Element, factory: dom.AtomFactory
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
      else:
        assert off, $resp.code
    ,
  )

proc fetchHTMLImageResource(
    view: WebRenderer, element: tags.HTMLImageElement, factory: dom.AtomFactory
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
    view: WebRenderer, element: tags.HTMLScriptElement, document: dom.Document
) =
  if view.opts.disableScripting:
    return

  let srcAttr = element.getAttr(element.document.factory, "src")
  let isInline = !srcAttr

  var codeBuffer: string # TODO: Prealloc somehow?

  element.script = Script(baseURL: view.target, document: document)

  if isInline:
    for child in element.childList:
      if child of dom.Text:
        codeBuffer &= Text(child).data
  else:
    let
      resolved = view.resolveURLSegment(&srcAttr)
      async = *element.getAttr(element.document.factory, "async")

    assert(*resolved, &srcAttr)

    if not async:
      warn "TODO: Sync script fetch not supported yet, loading script asynchronously",
        src = &srcAttr

    discard view.loader.getAsyncStream(
      &resolved,
      finalize = proc(resp: Response, err: TransportError) =
        if resp.code == 200:
          if not view.opts.disableScripting:
            element.script = Script(baseURL: &resolved, document: document)
            executeScript(element, resp.body.stream.readAll())
            view.scripts &= element
      ,
    )

  if isInline:
    executeScript(element, ensureMove(codeBuffer))
    view.scripts &= element

proc handleHTMLMetaElement(view: WebRenderer, element: HTMLMetaElement) =
  if !element.httpEquiv:
    return # TODO: We should probably handle other metadata tags too..

  let httpEquiv = &element.httpEquiv
  case httpEquiv
  of HTTPEquiv.Refresh:
    let dataOpt = parseRefreshData(&element.content, some(view.target))
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

proc loadHTMLStream(view: WebRenderer, stream: Stream) =
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
  view.dom.url = view.target

  #!fmt: off
  view.dom.cookies = view.cookieJar
    .match(view.target)
    .sortedByIt(it.path.len)
    .reversed()
  #!fmt: on

  userAgent.close()

  let title = getDocumentTitle(view.dom)
  if *title:
    view.client.encoder.encode(MasterOp.SetPageTitle)
    view.client.encoder.push(&title)
    assert *view.client.send()

  # if *title:
  #  view.app.setTitle(&"{&title} — Sirius")

  if (let htmlElem = view.dom.html(); *htmlElem) and
      (let langAttrib = getAttr(&htmlElem, view.dom.factory, "lang"); *langAttrib):
    view.dom.language = langAttrib

  view.reflow()
  view.renderCtx.viewerPosition = vec2(0, 0)

  # view.app.setCursorShape(Shape.Default)

  stream.close()

proc loadFile(view: WebRenderer, path: string) =
  loadHTMLStream(view, openFileStream(path))

proc showTransportErrorPage(view: WebRenderer, url: URL, err: TransportError) =
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

proc cleanup(view: WebRenderer) =
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

proc loadImageStream(view: WebRenderer, resp: Response) =
  let imageViewerTemplate =
    &view.assetProvider.openAssetStream("resources/image-viewer.html")
  let viewerTemplate =
    imageViewerTemplate.readAll() %
    [(&resp.url).pathname.strip(chars = {'/'}), resp.body.stream.encodeBase64()]

  imageViewerTemplate.close()

  view.loadHTMLStream(newStringStream(viewerTemplate))

proc parseAndHandleCookie(view: WebRenderer, cookieStr: string) =
  let parsed = parseCookie(view.target, cookieStr)
  if !parsed:
    warn "Failed to parse cookie! Is it malformed?", buffer = cookieStr
    return

  view.dom.cookies &= &parsed

proc handleResponseHeaders(view: WebRenderer, headers: HttpHeaders) =
  for hdr in headers:
    if cmpIgnoreCase(hdr.name, "set-cookie") == 0:
      view.parseAndHandleCookie(hdr.value)

proc loadStream(view: WebRenderer, resp: Response) =
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

proc buildRequestHeaders(view: WebRenderer, url: URL): HttpHeaders =
  let cookies = view.cookieJar.match(url)
  var cookieBuffer: string # TODO: Preallocate

  let cookiesList = reversed(cookies.sortedByIt(it.path.len))

  for i, cookie in cookiesList:
    cookieBuffer &= cookie.serialize(last = i == cookiesList.len - 1)

  var headers = emptyHttpHeaders()
  headers["Set-Cookie"] = ensureMove(cookieBuffer)

  ensureMove(headers)

proc loadUrl(view: WebRenderer, url: URL) =
  info "Loading page", dest = url

  view.target = url
  # view.app.setCursorShape(Shape.Progress)

  view.dom = Document(url: url)
  discard view.loader.getAsyncStream(
    url = url,
    timeoutMs = 60000,
    headers = view.buildRequestHeaders(url),
    finalize = proc(resp: Response, err: TransportError) =
      if err.kind == TransportErrorKind.None:
        view.loadStream(resp)
      else:
        error "An error occurred while fetching the requested content",
          message = err.message
        view.showTransportErrorPage(url, err),
  )

proc loadSiriusURL(view: WebRenderer, path: string) =
  if path == "new":
    let newTabPage = &view.assetProvider.openAssetStream("resources/new-tab.html")

    loadHTMLStream(
      view,
      newStringStream(
        newTabPage.readAll().multiReplace(
          {"{agent.name}": branding.AgentName, "{agent.version}": branding.AgentVersion}
        )
      ),
    )
    return

  assert(off, &"Unknown page sirius:{path}") # TODO: make this a page or something

proc loadNotSpecialURL(view: WebRenderer, target: URL) =
  # It'd be so much nicer if these were called special URLs, but sadly I didn't write this spec. :(

  if target.scheme == "sirius":
    loadSiriusURL(view, target.pathname)

proc loadPage*(view: WebRenderer, target: string) =
  view.target = parseURL(target)
  view.realm = newRealm()
    # TODO: Can all scripts in the same context share one realm, hopefully?
  debug "Load page", target = view.target, scheme = view.target.scheme

  case getSchemeType(view.target)
  of SchemeType.Ws, SchemeType.Ftp, SchemeType.Wss:
    assert off, "Not supported"
  of SchemeType.NotSpecial:
    loadNotSpecialURL(view, view.target)
  of SchemeType.Http, SchemeType.Https:
    loadURL(view, view.target)
  of SchemeType.File:
    loadFile(view, view.target.host & view.target.pathname)

proc applyCursorState(view: WebRenderer, layoutNode: LayoutNode) =
  if !layoutNode.cursor:
    return

  # HACK: This is just here to handle button input elements for now. Fix it once the CSS side can handle this.
  if layoutNode.domNode of tags.HTMLInputElement and
      HTMLInputElement(layoutNode.domNode).kind in
      [some(InputKind.Submit), some(InputKind.Button)]:
    # TODO: Send cursor shapes to master
    # view.app.setCursorShape(Shape.Grabbing)
    return

  # Source: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/cursor
  #[ let cursorMap = toTable {
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
  } ]#
  let cursor = &layoutNode.cursor

  #[ if cursor in cursorMap:
    let shape = cursorMap[cursor]

    if shape == Shape.Default and view.progress:
      discard # view.app.setCursorShape(Shape.Progress)
    else:
      discard # view.app.setCursorShape(shape) ]#

proc submitInputElement(view: WebRenderer, element: HTMLInputElement) =
  let ownerOpt = element.resetFormOwner()

  if !ownerOpt:
    return

  # FIXME: This isn't compliant yet. It just works for some cases.

  let owner = &ownerOpt

  if dispatchEvent(owner, "submit", undefined(view.realm.heap)):
    return

  let meth = owner.meth.get(otherwise = FormMethod.Get)
  var target =
    if *owner.action:
      &view.resolveURLSegment(&owner.action)
    else:
      view.target

  case meth
  of FormMethod.Get:
    target.query = some(&collectAndEncodeForm(owner))

    view.loadURL(ensureMove(target))
      # sigh... i know this isn't the right way. want to fight me about it?
  else:
    warn "Unhandled form method, ignoring submission attempt",
      meth = meth, action = target

proc handleFocusedDomElement(
    view: WebRenderer,
    layoutNode: LayoutNode,
    element: dom.Element,
    clicked: bool = false,
): bool {.discardable.} =
  applyCursorState(view, layoutNode)

  if clicked:
    if dispatchEvent(layoutNode.domNode, "click", undefined(view.realm.heap)):
      # If JS code ends up handling this event and asks us to prevent
      # default behavior, we must comply (albeit this is not fully implemented yet) 

      # FIXME: pass an actual Event object instead of undefined
      return

    if element of tags.HTMLAnchorElement:
      let anchorElement = HTMLAnchorElement(element)
      if *anchorElement.href:
        # TODO: The styling engine needs to support :not so that if an anchor element
        # doesn't have a href, it should _NOT_ appear as clickable due to `cursor: pointer`
        # in Sirius' UA stylesheet globally applied to all anchors.
        loadURL(view, &view.resolveURLSegment(&anchorElement.href))
    elif element of tags.HTMLInputElement:
      let inputElement = HTMLInputElement(element)
      let kind =
        if *inputElement.kind:
          &inputElement.kind
        else:
          InputKind.Text

      case kind
      of InputKind.Submit:
        submitInputElement(view, inputElement)
      else:
        discard

    view.keyboardFocusedElement = some(element)
    return true

proc handleFocusedElement(view: WebRenderer, clicked: bool = false) =
  if !view.focusedElement:
    # view.app.setCursorShape(if view.progress: Shape.Progress else: Shape.Default)
    return

  let elem = &view.focusedElement
  if elem.domNode of dom.Element:
    handleFocusedDomElement(view, elem, Element(elem.domNode), clicked = clicked)

proc handleWindowResize(view: WebRenderer, viewportSize: IVec2) =
  view.renderCtx.resize(vec2(viewportSize))
  view.reflow()

proc executeOneMacrotask(view: WebRenderer) =
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

proc poll*(view: WebRenderer) =
  view.loader.poll()
  view.progress = view.loader.pendingAssets.len > 0 or view.loader.retryQueue.len > 0

  view.executeOneMacrotask()

proc handleKeyboardEvent(view: WebRenderer) =
  let keysym = XKBKeysym(0) # view.app.xkbState.getOneSym(event.key.code + 8)
  if *view.keyboardFocusedElement:
    let element = &view.keyboardFocusedElement

    discard dispatchEvent(element, "keydown", undefined(view.realm.heap))
    # not sure this is really compliant...
    # FIXME: pass an actual Event object instead of undefined

    if element of HTMLInputElement:
      let inputElement = HTMLInputElement(element)
      if keysym == XKB_Key_Backspace:
        if inputElement.inputBuffer.len > 0:
          inputElement.inputBuffer =
            inputElement.inputBuffer[0 ..< inputElement.inputBuffer.len - 1]

          view.reflow()
        return

      if keysym != XKB_Key_Shift_L and keysym != XKB_Key_Shift_R and
          keysym != XKB_Key_Tab and keysym != XKB_Key_Super_L and
          keysym != XKB_Key_Super_R and keysym != XKB_Key_Return:
        # FIXME: probably can be cleaner?
        # TODO: Bring this back
        # inputElement.inputBuffer &= Rune(view.app.xkbState.getUtf32(event.key.code + 8))
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

proc loop*(view: WebRenderer): int =
  info "Entering main loop"

  var lastDmabufFd = -1'i32 # HACK: looks bad tbh.
  while true:
    let msgOpt = view.client.blockForMessage(RenderOp)
    if !msgOpt:
      break

    let msg = &msgOpt
    case msg.op
    of RenderOp.GotoURL:
      view.loadPage(&msg.argument(0, string))
    of RenderOp.DrawFrame:
      view.renderCtx.drawTree()

      if view.dom.edited:
        view.reflow()
        view.dom.edited = false

      let dmabufFd = VulkanContext(view.renderCtx.fig.ctx).exportBufferFd()

      view.client.encoder.encode(MasterOp.FrameDrawn)
      discard view.client.send()

      if lastDmabufFd != dmabufFd:
        view.client.encoder.encode(MasterOp.UseGraphicsFD)
        view.client.encoder.push(FileDescriptor(dmabufFd))
        # debugecho &"update fd {lastDmabufFd} => {dmabufFd}"
        lastDmabufFd = dmabufFd
        assert *view.client.send()
    of RenderOp.Close:
      break
    of RenderOp.ResizeRenderTarget:
      let dims = &msg.argument(0, vmath.IVec2)
      handleWindowResize(view, dims)
      view.renderCtx.drawTree()

      view.client.encoder.encode(MasterOp.FrameDrawn)
      assert *view.client.send()

      view.client.encoder.encode(MasterOp.TargetResized)
      view.client.encoder.push(dims)
      view.client.encoder.push(
        VulkanContext(view.renderCtx.fig.ctx).exportBufferStride()
      )
      assert *view.client.send()

      if lastDmabufFd >= 0'i32:
        view.client.encoder.encode(MasterOp.UseGraphicsFD)
        view.client.encoder.push(FileDescriptor(lastDmabufFd))
        assert *view.client.send()

    #[ view.poll()

    if not view.progress and (view.target != view.dom.url):
      view.loadURL(view.dom.url)

    let eventOpt = view.app.flushQueue()
    if !eventOpt:
      continue

    let event = &eventOpt
    case event.kind
    of EventKind.RedrawRequested:
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
      discard # debug "Unhandled surfer event", kind = event.kind ]#

  info "Exiting main loop"
  VulkanContext(view.renderCtx.fig.ctx).releaseBackendResources()

  print view.dom.cookies
  if *view.target.hostname:
    view.cookieJar.domains[&view.target.hostname] = view.dom.cookies

  view.cookieJar.collect()
  view.cookieJar.write()
  return 0
