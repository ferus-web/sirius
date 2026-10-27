## Low-level Nim bindings to GMP
##
## Copyright (C) 2024-2026 Trayambak Rai (xtrayambak@disroot.org)

when defined(windows):
  {.passL: "-lgmp".}

type
  mp_limb_t* = BiggestUint
  mp_bitcnt_t* = BiggestUint
  mpz_struct* {.importc: "__mpz_struct", header: "<gmp.h>".} = object

  mpz_t* = array[1, mpz_struct]

  gmp_randalg_t* {.importc, header: "<gmp.h>".} = enum
    GMP_RAND_ALG_LC = 0

{.push importc, header: "<gmp.h>".}
# Initializating Integers
proc mpz_init*(mpz_ptr: ptr mpz_t)
proc mpz_init2*(mpz_ptr: ptr mpz_t, bitcnt: mp_bitcnt_t)
proc mpz_clear*(x: ptr mpz_t)

# Assigning Integers
proc mpz_set_str*(mpz_ptr: ptr mpz_t, str: cstring, size: cint): cint
proc mpz_set*(rop: ptr mpz_t, op: mpz_t)
proc mpz_set_ui*(rop: ptr mpz_t, op: cint)
proc mpz_set_si*(rop: ptr mpz_t, op: cint)
proc mpz_set_d*(rop: ptr mpz_t, op: float)
proc mpz_swap*(a, b: ptr mpz_t)

# Simultaneous Integer Init and Assignment
proc mpz_init_set*(rop: ptr mpz_t, op: mpz_t)
proc mpz_init_set_ui*(rop: ptr mpz_t, op: cuint)
proc mpz_init_set_si*(rop: ptr mpz_t, op: cint)
proc mpz_init_set_d*(rop: ptr mpz_t, op: cdouble)
proc mpz_init_set_str*(rop: ptr mpz_t, op: cstring)

# Integer Arithmetic
proc mpz_add*(rop: ptr mpz_t, op1, op2: mpz_t)
proc mpz_add_ui*(rop: ptr mpz_t, op1: mpz_t, op2: cuint)

proc mpz_sub*(rop: ptr mpz_t, op1, op2: mpz_t)
proc mpz_sub_ui*(rop: ptr mpz_t, op1: mpz_t, op2: cuint)
proc mpz_ui_sub*(rop: ptr mpz_t, op1: cuint, op2: ptr mpz_t)

proc mpz_mul*(rop: ptr mpz_t, op1, op2: mpz_t)
proc mpz_mul_si*(rop: ptr mpz_t, op1: mpz_t, op2: cint)
proc mpz_mul_ui*(rop: ptr mpz_t, op1: mpz_t, op2: cuint)

proc mpz_addmul*(rop: ptr mpz_t, op1, op2: mpz_t)
proc mpz_addmul_ui*(rop: ptr mpz_t, op1: mpz_t, op2: cuint)

proc mpz_submul*(rop: ptr mpz_t, op1, op2: mpz_t)
proc mpz_submul_ui*(rop: ptr mpz_t, op1: mpz_t, op2: cuint)

proc mpz_mul_2exp*(rop: ptr mpz_t, op1: mpz_t, op2: mp_bitcnt_t)

proc mpz_neg*(rop: ptr mpz_t, op: mpz_t)
proc mpz_abs*(rop: ptr mpz_t, op: mpz_t)

# Integer Exponentiation
proc mpz_powm*(rop: ptr mpz_t, base, exp, `mod`: mpz_t)
proc mpz_powm_ui*(rop: ptr mpz_t, base: mpz_t, exp: BiggestUint, `mod`: mpz_t)

proc mpz_powm_sec*(rop: ptr mpz_t, base, exp, `mod`: mpz_t)

proc mpz_pow*(rop: ptr mpz_t, base: mpz_t, exp: cuint)
proc mpz_ui_pow_ui*(rop: ptr mpz_t, base, exp: cuint)

# Integer Comparison
proc mpz_cmp*(op1, op2: mpz_t): cint
proc mpz_cmp_d*(op1: mpz_t, op2: cdouble): cint
proc mpz_cmp_si*(op1: mpz_t, op2: int64): cint
proc mpz_cmp_ui*(op1: mpz_t, op2: uint64): cint

proc mpz_sgn*(op1: mpz_t): cint

# Integer Conversion
proc mpz_get_ui*(op: mpz_t): cuint
proc mpz_get_si*(op: mpz_t): cint
proc mpz_get_d*(op: mpz_t): cdouble
proc mpz_get_d_2exp*(exp: cint, op: mpz_t): BiggestFloat
proc mpz_get_str*(str: cstring, base: cint, op: mpz_t): cstring

{.pop.}
