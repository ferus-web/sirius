## Implementation of `SubmitEvent`
## https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#the-submitevent-interface
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import components/js/runtime/prelude, components/dom/dom

type SubmitEvent* = object
  submitter*: Hidden[dom.Element]
