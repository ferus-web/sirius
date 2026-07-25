import std/[math, options]
import components/js/runtime/vm/prelude
import pkg/shakar
import components/js/runtime/[types, bridge]
import components/js/stdlib/types/std_string_type
import components/js/runtime/abstract/to_primitive
import pkg/gmp

proc ToString*(runtime: Runtime, value: JSValue): string {.gcsafe.} =
  ## 7.1.17 ToString ( argument )
  ## The abstract operation ToString takes argument argument (an ECMAScript language value) and returns either a normal completion containing a String or a throw completion. It converts argument to a value of type String. It performs the following steps when called
  # # debug "runtime: toString(): " & value.crush()

  case value.kind
  of String: # 1. If argument is a String, return argument.
    return &value.getStr()
  of Undefined:
    # 3. If argument is undefined, return "undefined".
    return "undefined"
  of Object:
    if runtime.isA(value, JSString):
      return value.toNativeString()

    # 9. Assert: argument is an Object.
    # 10. Let primValue be ? ToPrimitive(argument, string).
    let primValue = runtime.ToPrimitive(value, some(String))

    # 12. Return ? ToString(primValue).
    if primValue != nil:
      return runtime.ToString(primValue)
  of Null, Ident:
    return "null" # 4. If argument is null, return "null".
  of Boolean:
    return $(&value.getBool())
      # 5. If argument is true, return "true"
      # 6. If argument is false, return "false".
  of Integer:
    return $(&value.getInt())
      # 7. If argument is a Number, return Number::toString(argument, 10).
  of BigInteger:
    return $value.bigint
  of Float:
    # 7. If argument is a Number, return Number::toString(argument, 10).

    let value = &getFloat(value)

    if value.isNaN:
      return "NaN"

    if value == Inf:
      return "Infinity"

    if value == -Inf:
      return "-Infinity"

    return $value
  of Sequence:
    var buffer = "["

    # FIXME: not spec compliant!
    for i, _ in value.sequence:
      buffer &= runtime.ToString(value.sequence[i].addr)
      if i < value.sequence.len - 1:
        buffer &= ", "

    buffer &= ']'

    return buffer
  of NativeCallable:
    # FIXME: not spec compliant!
    return "function () {\n      [native code]\n}"
  of BytecodeCallable:
    # FIXME: not spec compliant!
    return "function " & value.clauseName & "() { }"
