## Implementation of the `Performance` interface
## https://www.w3.org/TR/hr-time-3/#sec-performance
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/monotimes
import components/js/runtime/prelude
import pkg/shakar

type Performance* = object
  timeOrigin*: int64

proc generateGlobal*(rt: Runtime, timeOrigin: int64) =
  # TODO: This should be a property on `window`
  discard rt.setGlobal("performance", Performance(timeOrigin: timeOrigin))

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("Performance", Performance)
  runtime.definePrototypeFn(
    Performance,
    "now",
    proc(this: JSValue) =
      ## https://www.w3.org/TR/hr-time-3/#now-method
      ## The now() method MUST return the number of milliseconds in the current high resolution time given this’s relevant global object (a duration).
      ##
      ## The time values returned when calling the now() method on Performance objects with the same time origin MUST use the same monotonic clock. The difference between any two chronologically recorded time values returned from the now() method MUST never be negative if the two time values have the same time origin.

      # TODO: Harden this, it's too precise right now.
      # Maybe add some jitter and rubberbanding? (can't think of the appropriate
      # term right now, but basically: just return the same value for _veery_ close calls.
      # Alternatively, we could just strip off the entire floating point component entirely.
      let timeOrigin = &getInt(this.getSimpleProperty("timeOrigin"))
      let currTime = float64(getMonoTime().ticks() - timeOrigin)

      ret currTime / 1_000_000'f64
    ,
  )
