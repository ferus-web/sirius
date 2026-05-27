import std/[os, streams, tables]
import
  components/style/[user_agent, parser, matching],
  components/html/dom,
  components/layout/[flow, node_builder],
  webview/core
import pkg/[vmath, pretty]

proc main() {.inline.} =
  if paramCount() < 1:
    quit "Usage: sirius [path/to/file.html]"

  let view = initWebView()
  view.loadPage("file://" & paramStr(1))
  quit(view.loop())

when isMainModule:
  main()
