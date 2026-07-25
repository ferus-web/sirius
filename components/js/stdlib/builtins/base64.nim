## Base64 encoding/decoding
## These aren't part of the ECMAScript standard, but rather the HTML living spec.
## 
## Copyright (C) 2024-2026 Trayambak Rai (xtrayambak@disroot.org)

import std/[options]
import components/js/runtime/[arguments, types, bridge, construction]
import components/js/runtime/abstract/coercion
import components/js/stdlib/errors
import pkg/shakar

import components/impure/simdutf

proc generateStdIr*(runtime: Runtime) =
  # atob
  # Decode a base64 encoded string
  runtime.defineFn(
    "atob",
    proc() =
      if runtime.argumentCount() < 1:
        typeError(runtime, "atob: At least 1 argument required, but only 0 passed")
        return

      let
        value = runtime.RequireObjectCoercible(&runtime.argument(1))
        strVal = runtime.ToString(value)

      var buffer = newString(
        simdutf.base64LengthFromBinary(
          cast[uint64](strVal.len), {Base64Options.DefaultAcceptGarbage}
        )
      )
      var emitted = cast[uint64](buffer.len)

      let res = simdutf.base64ToBinarySafe(
        strVal[0].addr,
        length = cast[uint64](strVal.len),
        output = buffer[0].addr,
        outlen = emitted.addr,
        options = {Base64Options.DefaultAcceptGarbage},
        lastChunkOptions = LastChunkHandlingOptions.Loose,
        decodeUpToBadChar = false,
      )

      if res.error == ErrorCode.Success:
        ret str(runtime, ensureMove(buffer))
      else:
        runtime.typeError("atob: String contains an invalid character"),
  )

  # btoa
  # Encode a string into Base64 data
  runtime.defineFn(
    "btoa",
    proc() =
      let
        value = runtime.RequireObjectCoercible(
          &runtime.argument(
            1,
            required = true,
            message = "btoa: At least 1 argument required, but only {nargs} passed",
          )
        )
        str = runtime.ToString(value)
      var buffer = newString(
        simdutf.maximalBinaryLengthFromBase64(str[0].addr, cast[uint64](str.len))
      )

      buffer.setLen(
        simdutf.binaryToBase64(
          str[0].addr,
          cast[uint64](str.len),
          buffer[0].addr,
          {Base64Options.DefaultAcceptGarbage},
        )
      )
      ret str(runtime, ensureMove(buffer))
    ,
  )
