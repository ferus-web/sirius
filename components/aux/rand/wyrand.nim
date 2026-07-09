## wyrand implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import pkg/nint128, pkg/nint128/nint128_arithmetic

func wyrand*(state: var uint64): uint64 =
  state += 0xa0761d6478bd642f'u64

  let s = i128(state)
  var r = s xor i128(0xe7037ed1a0b428db'i64)
  r *= s

  cast[uint64](r.hi) xor r.lo
