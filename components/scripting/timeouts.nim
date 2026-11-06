## Implementation of routines for `setTimeout()` and `setInterval()`
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[deques, monotimes, times]
import
  components/js/runtime/[arguments, bridge, types],
  components/js/runtime/abstract/[to_number]
import pkg/shakar

proc generateBindings*(runtime: Runtime) =
  runtime.defineFn(
    "setInterval",
    proc() =
      let
        callback = &runtime.argument(1, required = true)
        delayMs = initDuration(
          milliseconds = int(runtime.ToNumber(&runtime.argument(2, required = true)))
        )

      runtime.macrotaskQueue.addLast(
        Task(
          callback: callback,
          delay: delayMs,
          deadline: getMonoTime() + delayMs,
          flags: {TaskFlag.Immortal},
        )
      ),
  )

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
