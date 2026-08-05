## Test suite for exceptionless number parsing routines
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/unittest
import pkg/shakar
import components/aux/parse_nums

suite "optional number parsing":
  test "basics for tryParseInt()":
    check(&tryParseInt("32") == 32)
    check(&tryParseInt("2147483647") == 2147483647)
    check(&tryParseInt("-32") == -32)
    check(&tryParseInt("-2147483648") == -2147483648)

    check(!tryParseInt("3irty2"))
    check(!tryParseInt("3.14"))

    check(&tryParseInt("9223372036854775807") == 9223372036854775807)
    check(!tryParseInt("9223372036854775808"))

  test "zero padded input for tryParseInt()":
    check(&tryParseInt("056") == 56)

  test "whitespace padded input for tryParseInt()":
    check(!tryParseInt("  67"))
      # NOTE: This is because this routine does not concern itself with fixing up data. That is the caller's job, and the caller in this case will often call TrimString prior to this function anyways.

  test "basics for tryParseUint()":
    check(&tryParseUint("32", uint8) == 32)
    check(&tryParseUint("2147483647", uint64) == 2147483647)

  test "overflow provided size for tryParseUint()":
    check(!tryParseUint("9223372036854775807", uint8))
    check(!tryParseUint("256", uint8))
    check(!tryParseUint("65537", uint16))
    check(!tryParseUint("4294967296", uint32))

  test "uint64 limits for tryParseUint()":
    check(&tryParseUint("9223372036854775807", uint64) == 9223372036854775807'u)
    check(&tryParseUint("9223372036854775809", uint64) == 9223372036854775809'u)

  test "tryParseUint() should ignore signed input":
    check(!tryParseUint("-32", uint8))
    check(!tryParseUint("-2147483648", uint8))
