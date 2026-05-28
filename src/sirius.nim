import std/os
import webview/core

proc main() {.inline.} =
  if paramCount() < 1:
    quit "Usage: sirius [path/to/file.html]"

  let view = initWebView()
  view.loadPage(paramStr(1))
  quit(view.loop())

when isMainModule:
  main()
