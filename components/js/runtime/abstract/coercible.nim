import components/js/runtime/vm/prelude
import components/js/runtime/types
import components/js/stdlib/errors

proc RequireObjectCoercible*(runtime: Runtime, value: JSValue): JSValue {.inline.} =
  if value.kind == Null:
    runtime.typeError("Object is not coercible: " & value.crush())
    return null(runtime.heapManager)

  value
