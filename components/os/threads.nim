## Thread-related utilities
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
when defined(unix):
  import components/impure/nix

import pkg/chronicles

logScope:
  topics = "os/threads"

proc setThreadName*(name: string) {.raises: [].} =
  if name.len < 1:
    return

  when nix.SupportsLinuxPrctls:
    discard nix.prctl(nix.PR_SET_NAME, cast[uint64](name[0].addr))
  else:
    warn "IMPLEMENTME: setThreadName() on non-Linux platforms"
