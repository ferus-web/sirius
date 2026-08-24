## Implementation of `Event`
## https://dom.spec.whatwg.org/#interface-event
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/js/runtime/prelude
import pkg/shakar

type
  EventPhase* {.pure, size: sizeof(uint8).} = enum
    None = 0
    CapturingPhase = 1
    AtTarget = 2
    BubblingPhase = 3

  EventInit* = object
    bubbles*, cancelable*, composed*: bool

  Event* = object of RootObj
    `type`*: JSValue
    target*, srcElement*, currentTarget*: JSValue
    composedPath*: JSValue

    eventPhase*: EventPhase

    bubbles*, cancelable*, returnValue*: bool
    isTrusted*: bool

    timeStamp*: float64

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("Event", Event)
  runtime.setProperty(Event, "NONE", EventPhase.None)
  runtime.setProperty(Event, "CAPTURING_PHASE", EventPhase.CapturingPhase)
  runtime.setProperty(Event, "AT_TARGET", EventPhase.AtTarget)
  runtime.setProperty(Event, "BUBBLING_PHASE", EventPhase.BubblingPhase)

  runtime.defineConstructor(
    "Event",
    proc() =
      let eventInitDict = runtime.argument(2, required = false) # TODO

      ret Event(
        `type`: &runtime.argument(
          1,
          required = true,
          message =
            "Event constructor: At least 1 argument required, but {nargs} passed",
        )
      )
    ,
  )
