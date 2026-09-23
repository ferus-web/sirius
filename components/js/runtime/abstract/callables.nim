## `IsCallable()` implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import
  components/js/runtime/vm/atom,
  components/js/runtime/[bridge, types],
  components/js/stdlib/types/std_function

proc IsCallable*(rt: Runtime, value: JSValue): bool =
  ## https://tc39.es/ecma262/#sec-iscallable
  ## The abstract operation IsCallable takes argument arg (an ECMAScript language value) and returns a Boolean.
  ## It determines if arg is a callable function with a [[Call]] internal method.

  # OPTIMIZATION: If value is an unboxed callable, return true immediately.
  if value.kind in {NativeCallable, BytecodeCallable}:
    return true

  # 1. If arg is not an Object, return false.
  if value.kind != Object:
    return false

  # 2. If arg has a [[Call]] internal method, return true.
  if rt.isA(value, JSFunction):
    return true

  # 3. Return false.
  false
