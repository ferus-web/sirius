## Implementation of routines for `setTimeout()`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[deques, monotimes, times]
import
  components/js/runtime/vm/atom,
  components/js/runtime/atom_helpers,
  components/js/runtime/[arguments, bridge, construction, types],
  components/js/runtime/abstract/[coercible, to_number, to_string],
  components/dom/dom,
  components/html/dom_utils,
  components/scripting/dom/[element]
import pkg/shakar

proc generateBindings*(runtime: Runtime) =
  runtime.defineFn(
    "setTimeout",
    proc() =
      let
        callback = &runtime.argument(1, required = true)
        delayMs = initDuration(
          milliseconds = int(runtime.ToNumber(&runtime.argument(2, required = true)))
        )

      runtime.macrotaskQueue.addLast(
        Task(callback: callback, delay: delayMs, deadline: getMonoTime() + delayMs)
      ),
  )
