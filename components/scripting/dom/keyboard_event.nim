## Implementation of `KeyboardEvent`
## https://www.w3.org/TR/uievents/#interface-keyboardevent
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

import components/js/runtime/prelude, components/scripting/dom/event
import pkg/[shakar, vmath]

type
  KeyLocation* {.pure, size: sizeof(uint8).} = enum
    Standard = 0x00
    Left = 0x01
    Right = 0x02
    Numpad = 0x03

  KeyboardEvent* = object of event.Event
    key*, code*: string
    location*: KeyLocation

    ctrlKey*, shiftKey*, altKey*, metaKey*: bool
    repeat*, isComposing*: bool

proc newKeyboardEvent*(
    key: string = "",
    code: string = "",
    location: KeyLocation = KeyLocation.Standard,
    repeat: bool = false,
    isComposing: bool = false,
): KeyboardEvent =
  KeyboardEvent(
    key: key, code: code, location: location, repeat: repeat, isComposing: isComposing
  )

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("KeyboardEvent", KeyboardEvent)
