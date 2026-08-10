## Core routines for WebView
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import pkg/[chronicles, results, shakar]
import components/synapse/[master, types, transport/socketpairs]
import ./[types, zygote]

logScope:
  topics = "webview/core"

proc loadPage*(view: WebView, target: string) =
  let sockPair = createSocketPair()
  assert(*sockPair, sockPair.error())

  # TODO: tabbed browsing? :3
  view.master.tabs &= Tab()
  view.master.spawn(0, ProcessKind.Renderer, &sockPair)
    # NOTE: the socketpair code will close the file descriptor itself

proc initWebView*(opts: WebViewOpts): WebView =
  WebView(opts: opts, master: initMaster(zygote.main))
