## Implementation of `throw` in MIR bytecode

import components/js/runtime/vm/prelude
import components/js/grammar/errors
import components/js/runtime/types
import components/js/stdlib/errors_common

proc typeError*(runtime: Runtime, message: string, exitCode: int = 1) {.inline.} =
  ## Meant for other Bali stdlib methods to use.
  runtime.vm[].throw(jsException("TypeError: " & message))
  runtime.logTracebackAndDie(exitCode)

proc rangeError*(runtime: Runtime, message: string, exitCode: int = 1) {.inline.} =
  runtime.vm[].throw(jsException("RangeError: " & message))
  runtime.logTracebackAndDie(exitCode)

proc referenceError*(runtime: Runtime, message: string, exitCode: int = 1) {.inline.} =
  runtime.vm[].throw(jsException("ReferenceError: " & message))
  runtime.logTracebackAndDie(exitCode)

proc syntaxError*(runtime: Runtime, message: string, exitCode: int = 1) {.inline.} =
  ## Meant for other Bali stdlib methods to use.
  runtime.vm[].throw(jsException("SyntaxError: " & message))
  runtime.logTracebackAndDie(exitCode)

proc syntaxError*(runtime: Runtime, error: ParseError, exitCode: int = 1) {.inline.} =
  runtime.syntaxError(error.message, exitCode)
