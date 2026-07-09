## Implementation of the Web Math API
##
## Copyright (C) 2024-2025 Trayambak Rai (xtrayambak at disroot dot org)

import std/[tables, math, options]
import components/js/runtime/vm/prelude
import components/js/runtime/[arguments, types, bridge]
import components/js/runtime/abstract/[to_number]
import components/aux/rand/wyrand
import pkg/shakar

type JSMath = object
  E*: float = math.E
  PI*: float = math.PI

proc generateStdIr*(runtime: Runtime) =
  runtime.registerType("Math", JSMath)
  runtime.setProperty(JSMath, "LN10", floating(runtime.realm.heap, math.ln(10'f64)))
  runtime.setProperty(JSMath, "LN2", floating(runtime.realm.heap, math.ln(2'f64)))
  runtime.setProperty(
    JSMath, "LOG10E", floating(runtime.realm.heap, math.log10(math.E))
  )
  runtime.setProperty(JSMath, "LOG2E", floating(runtime.realm.heap, math.log2(math.E)))
  runtime.setProperty(JSMath, "SQRT1_2", floating(runtime.realm.heap, math.sqrt(1 / 2)))
  runtime.setProperty(JSMath, "SQRT2", floating(runtime.realm.heap, math.sqrt(2'f64)))

  # Math.random
  # WARN: Do not use this for cryptography! This uses wyrand!
  runtime.defineFn(
    JSMath,
    "random",
    proc() {.gcsafe.} =
      ret float64(wyrand(runtime.rng)) / 1.8446744073709552e+19'f64
    ,
  )

  # Math.pow
  runtime.defineFn(
    JSMath,
    "pow",
    proc() =
      let
        value = runtime.ToNumber(&runtime.argument(1))
        exponent = runtime.ToNumber(&runtime.argument(2))

      ret pow(value, exponent)
    ,
  )

  # Math.cos
  runtime.defineFn(
    JSMath,
    "cos",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))
      ret cos(value)
    ,
  )

  # Math.sqrt
  runtime.defineFn(
    JSMath,
    "sqrt",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))
      ret sqrt(value)
    ,
  )

  # Math.tanh
  runtime.defineFn(
    JSMath,
    "tanh",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))

      ret tanh(value)
    ,
  )

  # Math.sin
  runtime.defineFn(
    JSMath,
    "sin",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))

      ret sin(value)
    ,
  )

  # Math.sinh
  runtime.defineFn(
    JSMath,
    "sinh",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))

      ret sinh(value)
    ,
  )

  # Math.tan
  runtime.defineFn(
    JSMath,
    "tan",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))

      ret tan(value)
    ,
  )

  # Math.trunc
  runtime.defineFn(
    JSMath,
    "trunc",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))

      ret trunc(value)
    ,
  )

  # Math.floor
  runtime.defineFn(
    JSMath,
    "floor",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))

      ret floor(value)
    ,
  )

  # Math.ceil
  runtime.defineFn(
    JSMath,
    "ceil",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))

      ret ceil(value)
    ,
  )

  # Math.cbrt
  runtime.defineFn(
    JSMath,
    "cbrt",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))

      ret cbrt(value)
    ,
  )

  # Math.log
  runtime.defineFn(
    JSMath,
    "log",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))

      ret ln(value)
    ,
  )

  # Math.abs
  runtime.defineFn(
    JSMath,
    "abs",
    proc() =
      let value = runtime.ToNumber(&runtime.argument(1))

      ret abs(value)
    ,
  )

  # Math.max
  runtime.defineFn(
    JSMath,
    "max",
    proc() =
      let
        a = runtime.ToNumber(&runtime.argument(1))
        b = runtime.ToNumber(&runtime.argument(2))

      ret max(a, b)
    ,
  )

  # Math.min
  runtime.defineFn(
    JSMath,
    "min",
    proc() =
      let
        a = runtime.ToNumber(&runtime.argument(1))
        b = runtime.ToNumber(&runtime.argument(2))

      ret min(a, b)
    ,
  )
