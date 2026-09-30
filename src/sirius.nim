## Sirius is an independent web rendering engine and browser written from scratch in Nim.
import std/[os, strformat]
import browser/app, webview/[branding, core, types], argparser
import pkg/[results, url]

proc showHelp() =
  echo &"""{branding.AgentName} (v{branding.AgentVersion}) is a web rendering engine and browser built from scratch in Nim.

Copyright (C) 2026 Trayambak Rai

Usage: {getAppFilename()} [ options ] [ URL ]

Where options are:
  --disable-image-loading        Refrain from loading image assets, when encountered.
  --disable-external-stylesheets Refrain from fetching and parsing external stylesheets linked to a web page.
  --disable-styling              Refrain from parsing stylesheets embedded within a web page.
  --disable-scripting            Refrain from fetching, parsing, compiling and executing guest JavaScript code both embedded on a page, as well as external scripts linked to it.

The URL must be a well-formed one, as per the WHATWG specifications (https://url.spec.whatwg.org/). This interface will make no attempts to normalize it.
"""

proc main() {.inline.} =
  let args = parseInput()
  if args.enabled("help", "h"):
    showHelp()
    quit(0)

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
