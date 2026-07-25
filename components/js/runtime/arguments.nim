import std/[options, strutils]
import components/js/runtime/vm/atom
import components/js/runtime/vm/interpreter/interpreter
import components/js/runtime/[types]
import components/js/stdlib/errors

proc argument*(
    runtime: Runtime, position: Natural, required: bool = false, message: string = ""
): Option[JSValue] =
  ## Get an argument from the call arguments register.
  ## If `required` is `true`, then a TypeError with an error message of your choice will be thrown.
  ## This routine is guaranteed to return a value when `required` is set to `false`, which it is by default.
  ##
  ## Error message substitutions:
  ## `{nargs}` - the number of arguments currently in the call arguments register
  assert(position > 0, "argument() only accepts naturals.")

  if runtime.vm.registers.callArgs.len < position:
    if required:
      let msg = message.multiReplace({"{nargs}": $runtime.vm.registers.callArgs.len})

      typeError(runtime, msg)
      return
    else:
      return some(undefined(runtime.realm.heap))

  some(runtime.vm.registers.callArgs[position - 1])
