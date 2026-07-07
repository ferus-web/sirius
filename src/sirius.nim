import std/os
import webview/[core, types], argparser

proc main() {.inline.} =
  let args = parseInput()
  if args.command.len < 1:
    quit "Usage: sirius [URL] [flags]"

  let view = initWebView(
    WebViewOpts(
      disableImageLoading: args.enabled("disable-image-loading"),
      disableExternalStylesheets: args.enabled("disable-external-stylesheets"),
      disableStyling: args.enabled("disable-styling"),
      disableScripting: args.enabled("disable-scripting"),
    )
  )
  view.loadPage(args.command)
  quit(view.loop())

when isMainModule:
  main()
