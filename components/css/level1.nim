## String maps for CSS Level 1 stuff
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, tables]
import components/css/types

const
  FloatMap* =
    toTable {"left": FloatMode.Left, "right": FloatMode.Right, "none": FloatMode.None}

  BorderStyleMap* = toTable {
    "none": BorderStyle.None,
    "dotted": BorderStyle.Dotted,
    "dashed": BorderStyle.Dashed,
    "solid": BorderStyle.Solid,
    "double": BorderStyle.Double,
    "groove": BorderStyle.Groove,
    "ridge": BorderStyle.Ridge,
    "inset": BorderStyle.Inset,
    "outset": BorderStyle.Outset,
  }

{.push inline.}

func getFloatMode*(value: string): Option[FloatMode] =
  ## **Note**: `value` must be fully lowercased already, this routine won't attempt to do that for you.
  if value in FloatMap:
    some(FloatMap[value])
  else:
    none(FloatMode)

func getBorderStyle*(value: string): Option[BorderStyle] =
  ## **Note**: `value` must be fully lowercased already, this routine won't attempt to do that for you.
  if value in BorderStyleMap:
    some(BorderStyleMap[value])
  else:
    none(BorderStyle)

{.pop.}
