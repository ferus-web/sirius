import std/os
import webview/[core, types], argparser

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

  let target = if args.command.len > 0: args.command else: "sirius:new"

  view.loadPage(target)
  # quit(view.loop())

when isMainModule:
  main()
