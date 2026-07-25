import std/[strutils, options]

proc parseNumberText*(text: string): Option[float] {.inline.} =
  try:
    return float(parseInt(text)).some()
  except ValueError as exc:
    try:
      return float(parseFloat(text)).some()
    except ValueError as exc:
      discard
