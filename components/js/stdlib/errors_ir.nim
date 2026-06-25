## Implementation of the error throw IR builtin
## Refactored here because Nim hates me
## Authors:
## Trayambak Rai (xtrayambak at disroot dot org)
import std/[logging, options]
import components/js/runtime/vm/prelude
import components/js/stdlib/errors_common
import components/js/runtime/[atom_helpers, arguments, types, bridge, wrapping]
import components/js/runtime/abstract/to_string
import pkg/shakar

type JSError* = object
  name*: string
  message*: string
  stack*: string # TODO: error stack implementation

proc generateStdIr*(runtime: Runtime) =
  info "errors: generate IR interface"
  runtime.registerType(name = "Error", JSError)
  if runtime.deathCallback == nil:
    runtime.deathCallback = DefaultDeathCallback
  runtime.definePrototypeFn(
    JSError,
    "toString",
    proc(self: JSValue) =
      ret runtime.getProperty(self, "message")
    ,
  )

  runtime.vm[].registerBuiltin(
    "BALI_THROWERROR",
    proc(op: Operation) =
      let atom = &runtime.argument(
        1,
        required = true,
        message = "BUG: BALI_THROWERROR got {nargs} atoms, expected one!",
      )

      var error = runtime.createObjFromType(JSError)

      error["name"] = runtime.wrap("Error") # TODO: custom error types
      error["message"] = runtime.wrap(atom)

      runtime.vm.registers.error = some(ensureMove(error))
        # Set the error register to this.

      runtime.vm[].throw(jsException(runtime.ToString(atom)))
      runtime.logTracebackAndDie(),
  )
