import std/[strutils, options]

proc parseNumberText*(text: string): Option[float] {.inline.} =
  # TODO: Replace this atrocity with exceptionless routines
  try:
    return float(parseInt(text)).some()
  except ValueError:
    try:
      return float(parseFloat(text)).some()
    except ValueError:
      discard
