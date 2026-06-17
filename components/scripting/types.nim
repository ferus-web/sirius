## Routines and types for scripting
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/js/grammar/prelude, components/js/runtime/prelude
import pkg/url

type Script* = ref object
  baseURL*: url.URL

  rt*: Runtime
  ast*: AST
