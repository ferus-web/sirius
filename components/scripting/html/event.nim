## Implementation of `Event`
## https://dom.spec.whatwg.org/#interface-event
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/js/runtime/prelude

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

    timestamp*: float64
