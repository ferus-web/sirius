## Front-facing routines to throw exceptions in a JavaScript execution context
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options
import
  components/js/runtime/[atom_helpers, types],
  components/js/runtime/vm/atom,
  components/js/runtime/vm/interpreter/interpreter,
  components/js/stdlib/errors_common
import pkg/shakar

proc throw*[T: object](
    rt: Runtime,
    _: typedesc[T],
    err: JSValue,
    message: string,
    name: Option[string] = none(string),
) =
  # NOTE: Maybe we should turn the str's into JSString or something.
  err["name"] = str(
    rt.realm.heap,
    if *name:
      &name
    else:
      $T,
  )
  err["message"] = str(rt.realm.heap, message)
  err["stack"] =
    if (let stackMessage = rt.vm[].generateTraceback(); *stackMessage):
      str(rt.realm.heap, &stackMessage)
    else:
      null(rt.realm.heap)

  rt.vm.registers.error = some(err)
  rt.vm[].throw(JSException())
  rt.logTracebackAndDie()

proc typeError*(rt: Runtime, message: string) =
  rt.throw(TypeError, err = rt.createObjFromType(TypeError), message = message)

proc rangeError*(rt: Runtime, message: string) =
  rt.throw(
    errors_common.RangeError,
    err = rt.createObjFromType(errors_common.RangeError),
    message = message,
  )

proc referenceError*(rt: Runtime, message: string) =
  rt.throw(
    ReferenceError, err = rt.createObjFromType(ReferenceError), message = message
  )

proc syntaxError*(rt: Runtime, message: string) =
  rt.throw(SyntaxError, err = rt.createObjFromType(SyntaxError), message = message)
