## Routines to parse numbers, that do not depend on exceptions to signify failure.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options

func tryParseUint*[T: SomeUnsignedInt](
    value: openArray[char], typ: typedesc[T]
): Option[T] {.raises: [].} =
  if value.len < 1:
    return none(T)

  var pos = 0'u64
  let size = cast[uint64](value.len)

  const HighUint = high(T)

  var final: T
  while pos < size:
    let ch = value[pos]
    if ch < '0' or ch > '9':
      return none(T)

    let digit = cast[T](ord(ch) - ord('0'))
    if final > (HighUint - digit) div 10:
      return none(T)

    final = final * 10 + digit
    inc pos

  some(ensureMove(final))

func tryParseInt*(
    value: openArray[char], allowPositiveSign: bool = true
): Option[int64] {.raises: [].} =
  if value.len < 1:
    return none(int64)

  var
    pos = 0'u64
    sign = 1'i64

  let size = cast[uint64](value.len)

  if value[0] == '-':
    sign = -1'i64
    inc pos
  elif value[1] == '+':
    if not allowPositiveSign:
      return none(int64)

    inc pos

  if pos >= size:
    return none(int64)

  const HighInt = high(int64)

  var final: int64
  while pos < size:
    let ch = value[pos]
    if ch < '0' or ch > '9':
      return none(int64)

    let digit = ord(ch) - ord('0')
    if final > (HighInt - digit) div 10:
      return none(int64)

    final = final * 10 + digit
    inc pos

  some(ensureMove(final) * sign)
