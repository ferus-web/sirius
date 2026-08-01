## Implementation of `window`
## https://html.spec.whatwg.org/#the-window-object
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options
import
  components/dom/dom,
  components/js/runtime/prelude,
  components/js/stdlib/errors,
  components/scripting/dom/document
import pkg/[chronicles, results, shakar, url]

logScope:
  topics = "html/window"

type JSWindow* = object
  status*: string
  document*: JSValue

proc generateGlobal*(runtime: Runtime, document: JSValue) =
  discard runtime.setGlobal("window", JSWindow(status: "", document: document))

proc generateBindings*(runtime: Runtime) =
  runtime.registerType(name = "Window", prototype = JSWindow)

  runtime.definePrototypeFn(
    JSWindow,
    "focus",
    proc(this: JSValue) =
      info "Page is requesting focus."
        # TODO: Maybe we could implement this properly on Windows/OS X once we get to that some day (if ever, that is)?
    ,
  )
  runtime.definePrototypeFn(
    JSWindow,
    "blur",
    proc(this: JSValue) =
      warn "Window.prototype.blur() called, ignoring."
    ,
  )
  runtime.definePrototypeFn(
    JSWindow,
    "open",
    proc(this: JSValue) =
      ## https://html.spec.whatwg.org/#apis-for-creating-and-navigating-browsing-contexts-by-name

      # The open(url, target, features) method steps are to run the window open steps with url, target, and features.

      # TODO: Implement this.
      # 1. If the event loop's termination nesting level is nonzero, then return null.
      warn "TODO: window.open() step 1"

      # 2. Let sourceDocument be the entry global object's associated Document.
      let document =
        &runtime.getProperty(this, "document").getPrivateObject(dom.Document)

      # 3. Let urlRecord be null.
      # 4. If url is not the empty string:
      var urlRecord: Result[url.URL, url.ParseError]
      let urlObj = runtime.argument(1, required = false)

      if *urlObj:
        # 1. Set urlRecord to the result of encoding-parsing a URL given url, relative to sourceDocument.
        urlRecord = tryParseURL(runtime.ToString(&urlObj), some(document.url))

        # 2. If urlRecord is failure, then throw a "SyntaxError" DOMException.
        if !urlRecord:
          runtime.syntaxError($urlRecord.error())
          return

      # TODO: Implement the rest of the spec.
      warn "TODO: window.open() steps 5-18"
      document.url = &urlRecord,
  )
