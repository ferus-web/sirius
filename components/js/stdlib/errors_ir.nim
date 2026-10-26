## Implementation of the error throw builtin
## Refactored here because Nim hates me
## Copyright (C) 2024-2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options]
import components/js/runtime/vm/prelude
import components/js/stdlib/errors_common, components/js/stdlib/types/std_string_type
import components/js/runtime/[atom_helpers, arguments, types, bridge, wrapping]
import components/js/runtime/abstract/to_string
import pkg/shakar

proc generateBindings*(runtime: Runtime) =
  runtime.registerType(name = "Error", Error)
  runtime.registerType(name = "TypeError", TypeError)
  runtime.registerType(name = "RangeError", errors_common.RangeError)
  runtime.registerType(name = "ReferenceError", ReferenceError)
  runtime.registerType(name = "SyntaxError", SyntaxError)

  runtime.defineConstructor(
    "Error",
    proc() =
      let err = runtime.createObjFromType(Error)
      err["name"] = str(runtime.realm.heap, "Error")
      err["message"] = str(
        runtime.realm.heap, runtime.ToString(&argument(runtime, 1, required = true))
      )

      ret err
    ,
  )
  if runtime.deathCallback == nil:
    runtime.deathCallback = DefaultDeathCallback

  runtime.definePrototypeFn(
    Error,
    "toString",
    proc(self: JSValue) =
      ret runtime.getProperty(self, "message")
    ,
  )

  runtime.defineAccessor(
    Error,
    "name",
    FieldAccessor(
      getter: proc(this: JSValue) =
        ret newJSString(runtime, "Error")
    ),
  )

  runtime.vm[].registerBuiltin(
    "BALI_THROWERROR",
    proc(op: Operation) =
      # TODO: Make this a bytecode op
      let atom = &runtime.argument(
        1,
        required = true,
        message = "BUG: BALI_THROWERROR got {nargs} atoms, expected one!",
      )

      runtime.vm.registers.error = some(atom)

      runtime.vm[].throw(JSException())
      runtime.logTracebackAndDie(),
  )
