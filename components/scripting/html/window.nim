## Implementation of `window`
## https://html.spec.whatwg.org/#the-window-object
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/js/runtime/prelude
import pkg/chronicles

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
