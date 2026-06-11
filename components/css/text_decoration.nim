## Special string maps for text decoration
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, tables]
import components/css/types

const
  TextDecorationLineMap* = toTable {
    "none": TextDecorationLine.None,
    "underline": TextDecorationLine.Underline,
    "overline": TextDecorationLine.Overline,
    "line-through": TextDecorationLine.LineThrough,
  }

  TextDecorationStyleMap* = toTable {
    "solid": TextDecorationStyle.Solid,
    "double": TextDecorationStyle.Double,
    "dotted": TextDecorationStyle.Dotted,
    "dashed": TextDecorationStyle.Dashed,
    "wavy": TextDecorationStyle.Wavy,
  }

  TextUnderlineStyleMap* = toTable {
    "auto": TextUnderlineStyle.Auto,
    "under": TextUnderlineStyle.Under,
    "left": TextUnderlineStyle.Left,
    "right": TextUnderlineStyle.Right,
  }

{.push inline.}
func getTextDecorationLine*(value: string): Option[TextDecorationLine] =
  ## **Note**: `value` must be fully lowercased already, this routine won't attempt to do that for you.
  if value in TextDecorationLineMap:
    some(TextDecorationLineMap[value])
  else:
    none(TextDecorationLine)

func getTextDecorationStyle*(value: string): Option[TextDecorationStyle] =
  ## **Note**: `value` must be fully lowercased already, this routine won't attempt to do that for you.
  if value in TextDecorationStyleMap:
    some(TextDecorationStyleMap[value])
  else:
    none(TextDecorationStyle)

func getTextUnderlineStyle*(value: string): Option[TextUnderlineStyle] =
  ## **Note**: `value` must be fully lowercased already, this routine won't attempt to do that for you.
  if value in TextUnderlineStyleMap:
    some(TextUnderlineStyleMap[value])
  else:
    none(TextUnderlineStyle)
{.pop.}
