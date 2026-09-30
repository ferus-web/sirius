## This file contains routines to allocate memory buffers with the executable bit.
## **NOTE**: This should ONLY be used in tandem with a JIT's assembler and no other place!
##
## Copyright (C) 2025-2026 Trayambak Rai (xtrayambak at disroot dot org)

when defined(posix):
  import std/posix
  import components/impure/nix

proc allocateExecutableBuffer*(size: uint64, readable, writable: bool): pointer =
  var address: pointer
  discard posix_memalign(address.addr, sysconf(SC_PAGESIZE), size)
  discard mprotect(address, size.int32, PROT_NONE)

  address

proc setBufferProtection*(
    address: pointer, size: int64, readable, writable, executable: bool
) =
  when defined(posix):
    assert(size > 0 and size < cast[int64](int32.high))

    var flags: int32 = PROT_NONE
    if readable:
      flags = flags or PROT_READ
    if writable:
      flags = flags or PROT_WRITE
    if executable:
      flags = flags or PROT_EXEC

    discard mprotect(address, cast[int32](size), flags)
  else:
    {.warn: "Cannot enforce W^X on this platform. Owie.".}

proc releaseExecutableBuffer*(buffer: pointer) =
  when defined(windows):
    return # TODO: Implement this on Windows

  nix.free(buffer)
