## `std/parseopt` based argument parser
##
## Copyright (C) 2024-2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[os, parseopt, options, tables]

type Input* = object
  command*: string
  arguments*: seq[string]
  flags: Table[string, string]
  switches: seq[string]

proc enabled*(input: Input, switch: string): bool {.inline.} =
  input.switches.contains(switch)

proc enabled*(input: Input, switchBig, switchSmall: string): bool {.inline.} =
  input.switches.contains(switchBig) or input.switches.contains(switchSmall)

proc flag*(input: Input, value: string): Option[string] {.inline.} =
  if input.flags.contains(value):
    return some(input.flags[value])

proc parseInput*(): Input {.inline.} =
  var
    foundCmd = false
    input: Input

  let params = commandLineParams()
  var parser = initOptParser(params)
  while true:
    parser.next()
    case parser.kind
    of cmdEnd:
      break
    of cmdShortOption, cmdLongOption:
      if parser.val.len < 1:
        input.switches &= parser.key
      else:
        input.flags[parser.key] = parser.val
    of cmdArgument:
      if not foundCmd:
        input.command = parser.key
        foundCmd = true
      else:
        input.arguments &= parser.key

  input
