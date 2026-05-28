## Core routines for WebView
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, streams, strformat]
import ./types
import pkg/[chronicles, nanovg, shakar, url, vmath], pkg/surfer/app
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

  webview.net = newNetworkClient()

  webview

proc loadHTMLStream(view: WebView, stream: Stream) =
  stream.setPosition(0)

  let userAgent = view.assetProvider.openAssetStream("user-agent.css").get()

  view.dom = parseHTML(stream)
  view.stylesheet = parseStylesheet(newParser(newParserInput(userAgent.readAll())))
  userAgent.close()

  view.styleMap =
    resolveStyling(view.dom.childList[1], view.dom.factory, view.stylesheet)
  view.tree = buildLayoutTree(view.dom.childList[1], view.styleMap, view.fontProvider)
  propagateStyles(view.tree, view.styleMap, view.fontProvider)

  view.renderCtx.tree = view.tree.clone()
  view.renderCtx.tree.computeLayout(
    vec2(0, 0), float32(view.app.windowSize.x), view.outputManager
  )

  stream.close()

proc loadFile(view: WebView, path: string) =
  loadHTMLStream(view, openFileStream(path))

proc loadUrl(view: WebView, url: URL) =
  let (resp, err) = view.net.getStream($url)
  echo err
  loadHTMLStream(view, resp.body.stream)

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

import pretty, tables
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
    else:
      discard # debug "Unhandled surfer event", kind = event.kind

  info "Exiting main loop"
  return 0
