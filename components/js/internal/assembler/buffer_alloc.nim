## This file contains routines to allocate memory buffers with the executable bit.
## **NOTE**: This should ONLY be used in tandem with a JIT's assembler and no other place!
##
## Copyright (C) 2025-2026 Trayambak Rai (xtrayambak at disroot dot org)
import components/js/platform/libc

proc allocateExecutableBuffer*(size: uint64, readable, writable: bool): pointer =
  when defined(windows):
    assert(
      (readable or writable) and not (not readable and writable),
      "Win32 does not support:\n* Non readable, writable buffers\n* Untouchable buffers (no read or write bits)",
    )
    var oldProt: DWORD
    let perms =
      if readable and writable:
        PAGE_EXECUTE_READWRITE
      elif readable and not writable:
        PAGE_READONLY
      else:
        unreachable

    return VirtualAlloc(NULL, size, MEM_COMMIT or MEM_RESERVE, perms)
  else:
    var address: pointer
    discard posix_malign(address.addr, sysconf(SC_PAGESIZE), size)
    discard mprotect(address, size.int32, PROT_NONE)

    return address

proc setBufferProtection*(
    address: pointer, size: int64, readable, writable, executable: bool
) =
  when defined(unix):
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

  libc.free(buffer)
