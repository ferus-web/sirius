## Routines and types for scripting
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/dom/dom, components/js/grammar/prelude, components/js/runtime/prelude
import pkg/url

type Script* = ref object
  baseURL*: url.URL
  document*: dom.Document

  rt*: Runtime
  ast*: AST
