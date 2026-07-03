## Constant values (like NaN, undefined, null, etc.)

import std/[logging]
import components/js/runtime/vm/ir/generator
import components/js/runtime/vm/[atom, prelude]
import components/js/runtime/types

proc generateStdIr*(runtime: Runtime) =
  if runtime.realm.constantsGenerated:
    return

  runtime.realm.constantsGenerated = true

  let params = IndexParams(priorities: @[vkGlobal])

  debug "constants: generating constant values"
  let undefined = runtime.index("undefined", params)
  runtime.ir.loadUndefined(undefined)

  let nan = runtime.index("NaN", params)
  runtime.ir.loadFloat(nan, stackFloating(NaN))

  let inf = runtime.index("Infinity", params)
  runtime.ir.loadFloat(inf, stackFloating(Inf))

  let vTrue = runtime.index("true", params)
  runtime.ir.loadBool(vTrue, true)

  let vFalse = runtime.index("false", params)
  runtime.ir.loadBool(vFalse, false)

  let null = runtime.index("null", params)
  runtime.ir.loadNull(null)
