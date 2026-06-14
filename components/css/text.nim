## Special string maps for text
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, tables]
import components/css/types

const WhitespaceMap* = toTable {
  "normal": Whitespace.Normal,
  "pre": Whitespace.Pre,
  "nowrap": Whitespace.NoWrap,
  "pre-wrap": Whitespace.PreWrap,
  "break-spaces": Whitespace.BreakSpaces,
  "pre-line": Whitespace.PreLine,
}

{.push inline.}

func getWhitespaceProperty*(value: string): Option[Whitespace] =
  ## **Note**: `value` must be fully lowercased already, this routine won't attempt to do that for you.
  if value in WhitespaceMap:
    some(WhitespaceMap[value])
  else:
    none(Whitespace)

{.pop.}
