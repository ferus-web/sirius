## Implementation of `MouseEvent`
## https://www.w3.org/TR/pointerevents4/#mouseevent
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/js/runtime/prelude, components/scripting/dom/event
import pkg/[shakar, vmath]

type MouseEvent* = object of event.Event
  screenX*, screenY*, clientX*, clientY*, layerX*, layerY*: int32
  ctrlKey*, shiftKey*, altKey*, metaKey*: bool

  button*: int16
  buttons*: uint16

  relatedTarget*: JSValue

proc newMouseEvent*(
    screenCoords, clientCoords, layerCoords: vmath.IVec2, button: int16, buttons: uint16
): MouseEvent =
  MouseEvent(
    screenX: screenCoords.x,
    screenY: screenCoords.y,
    clientX: clientCoords.x,
    clientY: clientCoords.y,
    layerX: layerCoords.x,
    layerY: layerCoords.y,
    button: button,
    buttons: buttons,
  )

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("MouseEvent", MouseEvent)
