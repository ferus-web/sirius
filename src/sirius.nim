import std/os
import webview/[core, types], argparser
import pretty, tables

proc main() {.inline.} =
  let args = parseInput()
  print args
  if args.command.len < 1:
    quit "Usage: sirius [URL] [flags]"

  let view = initWebView(
    WebViewOpts(
      disableImageLoading: args.enabled("disable-image-loading"),
      disableExternalStylesheets: args.enabled("disable-external-stylesheets"),
      disableStyling: args.enabled("disable-styling"),
    )
  )
  view.loadPage(args.command)
  quit(view.loop())

when isMainModule:
  main()
