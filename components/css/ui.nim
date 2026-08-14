## Special string maps for CSS UI level 3
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, tables]
import components/css/types

const CursorPredefinedMap* = toTable {
  "auto": CursorPredefined.Auto,
  "default": CursorPredefined.Default,
  "none": CursorPredefined.None,
  "context-menu": CursorPredefined.ContextMenu,
  "help": CursorPredefined.Help,
  "pointer": CursorPredefined.Pointer,
  "progress": CursorPredefined.Progress,
  "wait": CursorPredefined.Wait,
  "cell": CursorPredefined.Cell,
  "crosshair": CursorPredefined.Crosshair,
  "text": CursorPredefined.Text,
  "vertical-text": CursorPredefined.VerticalText,
  "alias": CursorPredefined.Alias,
  "copy": CursorPredefined.Copy,
  "move": CursorPredefined.Move,
  "no-drop": CursorPredefined.NoDrop,
  "not-allowed": CursorPredefined.NotAllowed,
  "grab": CursorPredefined.Grab,
  "grabbing": CursorPredefined.Grabbing,
  "e-resize": CursorPredefined.EResize,
  "n-resize": CursorPredefined.NResize,
  "ne-resize": CursorPredefined.NEResize,
  "nw-resize": CursorPredefined.NWResize,
  "s-resize": CursorPredefined.SResize,
  "se-resize": CursorPredefined.SEResize,
  "sw-resize": CursorPredefined.SWResize,
  "w-resize": CursorPredefined.WResize,
  "ew-resize": CursorPredefined.EWResize,
  "ns-resize": CursorPredefined.NSResize,
  "nesw-resize": CursorPredefined.NESWResize,
  "nwse-resize": CursorPredefined.NWSEResize,
  "col-resize": CursorPredefined.ColResize,
  "row-resize": CursorPredefined.RowResize,
  "all-scroll": CursorPredefined.AllScroll,
  "zoom-in": CursorPredefined.ZoomIn,
  "zoom-out": CursorPredefined.ZoomOut,
}

{.push inline.}

func getCursorPredefinedProperty*(value: string): Option[CursorPredefined] =
  ## **Note**: `value` must be fully lowercased already, this routine won't attempt to do that for you.
  if value in CursorPredefinedMap:
    some(CursorPredefinedMap[value])
  else:
    none(CursorPredefined)

{.pop.}
