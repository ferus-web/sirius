## Basic types for `JSString`.
## Separated from the String prototype functions to prevent circular dependencies. 

import
  components/js/runtime/vm/atom,
  components/js/runtime/atom_helpers,
  components/js/runtime/types
import pkg/shakar

type JSString* = object
  internal*: Hidden[JSValue]

proc newJSString*(runtime: Runtime, native: string): JSValue =
  ## Given a native string, turn it into a `JSString` allocated on the heap.
  var str = runtime.createObjFromType(JSString)
  str.tag("internal", str(runtime.heapManager, native))

  ensureMove(str)

proc toNativeString*(str: JSValue): string =
  ## Given a `JSValue`, assuming it is a proper `JSString`, convert it into its native string representation.
  &getStr(&str.tagged("internal"))
