## Sirius is an independent web rendering engine and browser written from scratch in Nim.
import std/os
import browser/app, webview/[core, types], argparser
import pkg/[results, url]

proc main() {.inline.} =
  let args = parseInput()
  let view = initWebView(
    WebViewOpts(
      disableImageLoading: args.enabled("disable-image-loading"),
      disableExternalStylesheets: args.enabled("disable-external-stylesheets"),
      disableStyling: args.enabled("disable-styling"),
      disableScripting: args.enabled("disable-scripting"),
    )
  )

  startBrowserShell(view, args)

when isMainModule:
  main()
