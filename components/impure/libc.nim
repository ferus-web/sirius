## libc primitives bindings
## Every routine that can be uniformly found across all supported platforms' C standard libraries goes here.
## For UNIX-specific ones, or further, Linux-specific ones, that goes into `components/impure/nix.nim` with kernel-specific guard flags, if required.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

{.push importc, header: "<stdlib.h>".}

proc free*(p: pointer)
proc malloc*(size: uint64): pointer

{.pop.}
