## High-level gmp wrapper
##
## Copyright (C) 2024-2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options]
import components/impure/gmp/bindings

type BigInt* = object
  bg*: mpz_t

proc `=destroy`*(big: BigInt) =
  mpz_clear(big.bg.addr) # free up the memory allocated for the bigint

{.push inline.}
proc cmp*(big: BigInt, u: SomeUnsignedInt): int =
  mpz_cmp_ui(big.bg, u.uint64)

proc cmp*(big: BigInt, i: SomeSignedInt): int =
  mpz_cmp_si(big.bg, i.int64)

proc cmp*(a, b: BigInt): int =
  mpz_cmp(a.bg, b.bg)

proc `==`*(a, b: BigInt): bool =
  cmp(a, b) == 0

proc `>`*(a, b: BigInt): bool =
  cmp(a, b) > 0

proc `<`*(a, b: BigInt): bool =
  cmp(a, b) < 0

proc `>=`*(a, b: BigInt): bool =
  a > b or a == b

proc `>`*(big: BigInt, n: SomeInteger): bool =
  big.cmp(n) > 0

proc `<`*(big: BigInt, n: SomeInteger): bool =
  big.cmp(n) < 0

proc `==`*(big: BigInt, n: SomeInteger): bool =
  big.cmp(n) == 0

proc `>=`*(big: BigInt, n: SomeInteger): bool =
  big > n or big == n

proc `+`*(a, b: BigInt): BigInt =
  var res: mpz_t
  mpz_init(res.addr)
  mpz_add(res.addr, a.bg, b.bg)

  BigInt(bg: move(res))

proc `+`*(a: BigInt, b: SomeUnsignedInt): BigInt =
  var res: mpz_t
  mpz_init(res.addr)
  mpz_add_ui(res.addr, a.bg, b.cuint)

  BigInt(bg: move(res))

proc `-`*(a: BigInt, b: SomeUnsignedInt): BigInt =
  var res: mpz_t
  mpz_init(res.addr)
  mpz_sub_ui(res.addr, a.bg, b.cuint)

  BigInt(bg: move(res))

proc `-`*(a: SomeUnsignedInt, b: BigInt): BigInt =
  var res: mpz_t
  mpz_init(res.addr)
  mpz_ui_sub(res.addr, a.cuint, b.bg)

  BigInt(bg: move(res))

proc `-`*(a, b: BigInt): BigInt =
  var res: mpz_t
  mpz_init(res.addr)
  mpz_sub(res.addr, a.bg, b.bg)

  BigInt(bg: move(res))

proc `*`*(a, b: BigInt): BigInt =
  var res: mpz_t
  mpz_init(res.addr)
  mpz_mul(res.addr, a.bg, b.bg)

  BigInt(bg: move(res))

proc `*`*(a: BigInt, b: SomeSignedInt): BigInt =
  var res: mpz_t
  mpz_init(res.addr)
  mpz_mul_si(res.addr, a.bg, b.cint)

  BigInt(bg: move(res))

proc `*`*(a: BigInt, b: SomeUnsignedInt): BigInt =
  var res: mpz_t
  mpz_init(res.addr)
  mpz_mul_ui(res.addr, a.bg, b.cuint)

  BigInt(bg: move(res))

proc `$`*(big: BigInt): string =
  $mpz_get_str(nil, 10, big.bg)

proc swap*(a, b: var BigInt) =
  mpz_swap(a.bg.addr, b.bg.addr)

proc getInt*(big: BigInt): Option[int] =
  if big > int.high:
    return

  some(mpz_get_si(big.bg).int)

proc getUint*(big: BigInt): Option[uint] =
  if big > uint.high or big < 0:
    return

  some(mpz_get_ui(big.bg).uint)

proc getFloat*(big: BigInt): float =
  mpz_get_d(big.bg).float

proc initBigInt*(i: SomeSignedInt): BigInt =
  var bg: BigInt
  mpz_init_set_si(bg.bg.addr, i.cint)

  bg

proc initBigInt*(s: string): BigInt =
  var bg: BigInt
  mpz_init(bg.bg.addr)
  if mpz_set_str(bg.bg.addr, s, 10) == -1:
    raise newException(ValueError, "Cannot parse as number: " & s)

  bg

{.pop.}
