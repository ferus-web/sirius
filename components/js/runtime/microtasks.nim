import std/deques
import components/js/runtime/types, components/js/runtime/vm/interpreter/interpreter

proc drainMicrotasks*(runtime: Runtime) =
  while runtime.microtaskQueue.len > 0:
    runtime.vm[].invoke(runtime.microtaskQueue.popFirst())
