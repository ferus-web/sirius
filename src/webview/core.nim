## Core routines for WebView
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, streams, strformat, strutils, sequtils]
import ./types
import pkg/[chronicles, shakar, url, vmath, xkb], pkg/surfer/app
import
  components/gfx/[core, init, font_loader],
  components/html/dom,
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
    ),
  )
  userAgent.close()

  let htmlElem = view.dom.childList.filterIt(
    it of dom.Element and tagType(Element(it)) == TAG_HTML
  )[0] # HACK: This is stupid. Do it properly.

  view.styleMap = resolveStyling(htmlElem, view.dom.factory, view.stylesheet)
  view.tree = buildLayoutTree(htmlElem, view.styleMap, view.fontProvider)
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
    view.net.getStream($url, timeoutMs = 5000) # TODO: Timeout should be customizable

  if err.kind == TransportErrorKind.None:
    loadHTMLStream(view, resp.body.stream)
  else:
    error "An error occurred while fetching the requested content",
      message = err.message
    showTransportErrorPage(view, url, err)

proc loadPage*(view: WebView, target: string) =
  let target = parseURL(target)
  debug "Load page", target = target, scheme = target.scheme

  case getSchemeType(target)
  of SchemeType.Ws, SchemeType.Ftp, SchemeType.Wss, SchemeType.NotSpecial:
    assert off, "Not supported"
  of SchemeType.Http, SchemeType.Https:
    loadUrl(view, target)
  of SchemeType.File:
    loadFile(view, target.host & target.pathname)

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
    else:
      discard # debug "Unhandled surfer event", kind = event.kind

  info "Exiting main loop"
  return 0
