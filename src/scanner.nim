## `scanner` is responsible for parsing IPDL (inter-process descriptor language) files and generating Nim bindings for the same.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

# TODO: Document this tool properly. It also needs a help interface

import
  std/[algorithm, options, os, osproc, parseutils, sets, sequtils, strformat, strutils]
import pkg/[results, shakar]
import ./argparser

type
  ArgType* {.pure, size: sizeof(uint8).} = enum
    String
    Uint8
    Uint16
    Uint32
    Uint64
    Int8
    Int16
    Int32
    Int64
    Bool
    URL
    IVec2
    Vec2
    FileDescriptor
    Varargs

  Arg = object
    typ: ArgType
    name: string
    optional: bool

  Operation = object
    name: string
    args: seq[Arg]

  Subsystem = object
    ops: seq[Operation]

  ParseError* = object
    pos*: int
    msg*: string

  Parser = object
    input: string
    pos: int

const Delimiters = Whitespace + {'(', ')', ';'}

func skipIgnored(p: var Parser) =
  while true:
    p.pos += skipWhitespace(p.input, p.pos)
    if p.pos + 1 < p.input.len and p.input[p.pos] == ';' and p.input[p.pos + 1] == ';':
      p.pos += skipUntil(p.input, '\n', p.pos)
    else:
      break

func peekChar(p: var Parser): Option[char] =
  p.skipIgnored()
  if p.pos < p.input.len:
    some(p.input[p.pos])
  else:
    none(char)

func expectChar(p: var Parser, c: char): Result[void, ParseError] =
  p.skipIgnored()
  if p.pos < p.input.len and p.input[p.pos] == c:
    inc p.pos
    ok()
  else:
    err(ParseError(pos: p.pos, msg: "expected '" & c & "'"))

func readAtom(p: var Parser): Option[string] =
  p.skipIgnored()
  var token: string
  let n = parseUntil(p.input, token, Delimiters, p.pos)
  if n == 0:
    none(string)
  else:
    p.pos += n
    some(token)

func parseArgType(raw: string): Option[ArgType] =
  case raw.toLowerAscii()
  of "string":
    some(ArgType.String)
  of "u8", "uint8":
    some(ArgType.Uint8)
  of "u16", "uint16":
    some(ArgType.Uint16)
  of "u32", "uint32":
    some(ArgType.Uint32)
  of "u64", "uint64":
    some(ArgType.Uint64)
  of "i8", "int8":
    some(ArgType.Int8)
  of "i16", "int16":
    some(ArgType.Int16)
  of "i32", "int32":
    some(ArgType.Int32)
  of "i64", "int64":
    some(ArgType.Int64)
  of "bool":
    some(ArgType.Bool)
  of "url":
    some(ArgType.URL)
  of "ivec2":
    some(ArgType.IVec2)
  of "vec2":
    some(ArgType.Vec2)
  of "fd":
    some(ArgType.FileDescriptor)
  of "varargs":
    some(ArgType.Varargs)
  else:
    none(ArgType)

func parseArg(p: var Parser): Result[Arg, ParseError] =
  &p.expectChar('(')
  p.skipIgnored()
  let
    typePos = p.pos
    rawTokenOpt = p.readAtom()
  if !rawTokenOpt:
    err(ParseError(pos: typePos, msg: "expected argument type"))
  else:
    let rawToken = &rawTokenOpt
    if not rawToken.startsWith('@'):
      err(ParseError(pos: typePos, msg: "argument type must start with '@'"))
    else:
      let
        withoutAt = rawToken[1 .. ^1]
        optional = withoutAt.endsWith('?')
        typeName =
          if optional:
            withoutAt[0 .. ^2]
          else:
            withoutAt
        typOpt = parseArgType(typeName)
      if typOpt.isNone:
        err(ParseError(pos: typePos, msg: "unknown argument type: " & typeName))
      else:
        p.skipIgnored()
        let
          namePos = p.pos
          nameOpt = p.readAtom()
        if nameOpt.isNone:
          err(ParseError(pos: namePos, msg: "expected argument name"))
        else:
          &p.expectChar(')')
          ok(Arg(typ: &typOpt, name: &nameOpt, optional: optional))

func parseOperation(p: var Parser): Result[Operation, ParseError] =
  &p.expectChar('(')
  p.skipIgnored()
  let
    kwPos = p.pos
    kwOpt = p.readAtom()
  if !kwOpt or &kwOpt != "op":
    err(ParseError(pos: kwPos, msg: "expected 'op'"))
  else:
    p.skipIgnored()
    let
      namePos = p.pos
      nameOpt = p.readAtom()
    if nameOpt.isNone:
      err(ParseError(pos: namePos, msg: "expected operation name"))
    else:
      var args: seq[Arg]
      while p.peekChar() == some('('):
        args.add(&p.parseArg())

      &p.expectChar(')')
      ok(Operation(name: &nameOpt, args: args))

func parseSubsystem(input: string): Result[Subsystem, ParseError] =
  var
    p = Parser(input: input, pos: 0)
    ops: seq[Operation] # NOTE: this can't be predictably preallocated

  while *p.peekChar():
    ops &= &p.parseOperation()
  ok(Subsystem(ops: ops))

func toNimIdent(ident: string): string =
  if ident.len < 2:
    return ident

  ident[0].toLowerAscii & ident[1 ..< ident.len]

func toNimType(typ: ArgType): string =
  case typ
  of ArgType.String:
    "string"
  of ArgType.Uint8:
    "uint8"
  of ArgType.Uint16:
    "uint16"
  of ArgType.Uint32:
    "uint32"
  of ArgType.Uint64:
    "uint64"
  of ArgType.Int8:
    "int8"
  of ArgType.Int16:
    "int16"
  of ArgType.Int32:
    "int32"
  of ArgType.Int64:
    "int64"
  of ArgType.Bool:
    "bool"
  of ArgType.URL:
    "url.URL"
  of ArgType.IVec2:
    "vmath.IVec2"
  of ArgType.Vec2:
    "vmath.Vec2"
  of ArgType.FileDescriptor:
    "FileDescriptor"
  of ArgType.Varargs:
    unreachable
    newString(0)

func emitArgumentsInSignature(isClient: bool, args: seq[Arg]): string =
  var buffer = newStringOfCap(48)
  if not isClient:
    buffer &= ", tab: uint32"

  for arg in args:
    var typ = toNimType(arg.typ)
    if arg.optional:
      typ = &"Option[{move(typ)}]"

    buffer &= &", {arg.name}: {move(typ)}"

  ensureMove(buffer)

func generateWrapper(
    subsystem: Subsystem, name: string, src: string, isClient, dontGenerateFns: bool
): string =
  var
    buffer = newStringOfCap(2048)
    imports: HashSet[string]

  imports.incl("pkg/[results, shakar]")
  if isClient:
    imports.incl("components/synapse/client")
  elif not dontGenerateFns:
    imports.incl("components/synapse/master")

  # professional import search
  for op in subsystem.ops:
    for arg in op.args:
      case arg.typ
      of ArgType.URL:
        imports.incl("pkg/url")
      of ArgType.IVec2, ArgType.Vec2:
        imports.incl("pkg/vmath")
      else:
        discard

  buffer &=
    &"""
## *Generated automatically by scanner. Do not edit!*
## **Source**: {src}
import std/options
import components/synapse/[encoder, types]
"""

  for imp in imports.toSeq().sortedByIt(it[0]):
    buffer &= &"import {imp}\n"

  let enumName = name & "Op"

  buffer &= "\ntype " & enumName & "* {.pure, size: sizeof(uint16).} = enum\n"
  for i, op in subsystem.ops:
    buffer &= &"  {op.name} = {i}\n"

  if dontGenerateFns:
    return ensureMove(buffer)

  buffer &= "\n# Sender API\n"
  let ctx = if isClient: "Client" else: "Master"
  for i, op in subsystem.ops:
    buffer &=
      &"""

proc {toNimIdent(op.name)}*(ctx: {ctx}{emitArgumentsInSignature(isClient, op.args)}) =
  ctx.encoder.encode({enumName}.{op.name})
"""

    for arg in op.args:
      if arg.optional:
        buffer &= &"  if *{arg.name}:"
        buffer &= "  \n  "

      buffer &= &"  ctx.encoder.push({arg.name})\n"

    if isClient:
      buffer &= "  ctx.send()\n"
    else:
      buffer &= "  ctx.send(&ctx.tabs[tab].renderer())\n"

  buffer &= "\n# Recipient API\n"
  # TODO: generate these at the top instead
  buffer &= "type"
  for op in subsystem.ops:
    buffer &= &"\n  {op.name}Params* = object\n"

    for arg in op.args:
      var typ = toNimType(arg.typ)
      if arg.optional:
        typ = &"Option[{move(typ)}]"

      buffer &= &"    {arg.name}*: {move(typ)}\n"

  buffer &=
    &"\nproc params*[T: object](msg: Message[{enumName}], _: typedesc[T]): Result[T, string] =\n"

  buffer &= "  var params: T\n"
  for op in subsystem.ops:
    let
      paramsStruct = op.name & "Params"
      argc = block:
        var
          hi = cast[uint32](op.args.len -
            op.args.countIt(it.typ == ArgType.FileDescriptor))
            # This is the maximum number of theoretical arguments this function can receive.
          lo = hi - cast[uint32](op.args.countIt(it.optional))
            # This is the least number of arguments we can get away with to execute this function, hopefully.

        for arg in op.args:
          if arg.typ == ArgType.Varargs:
            hi = uint32.high
            break

        (hi: hi, lo: lo)

    buffer &= &"\n  when T is {paramsStruct}:\n"
    buffer &= &"    # argc [high]: {argc.hi}; argc [low]: {argc.lo}\n\n"
    buffer &=
      &"    if msg.argc > {argc.hi}'u8 or msg.argc < {argc.lo}'u8: return err(&\"{op.name}: Argument count mismatch\")\n\n"

    var fdCount: uint8
    for i, arg in op.args:
      case arg.typ
      of ArgType.FileDescriptor:
        if arg.optional:
          buffer &= &"    params.{arg.name} = msg.fd({fdCount})\n"
        else:
          let optTmp = arg.name & "Opt"
          buffer &= &"    let {optTmp} = msg.fd({fdCount})\n"
          buffer &=
            &"    if !{optTmp}: return err(&\"{op.name}: Missing non-optional file descriptor '{arg.name}' at position {fdcount}\")\n"
          buffer &= &"    params.{arg.name} = &{optTmp}\n"

        inc fdCount
      else:
        if arg.optional:
          buffer &= &"    params.{arg.name} = msg.argument({i}, {toNimType(arg.typ)})\n"
        else:
          let optTmp = arg.name & "Opt"
          buffer &= &"    let {optTmp} = msg.argument({i}, {toNimType(arg.typ)})\n"
          buffer &=
            &"    if !{optTmp}: return err(\"{op.name}: Missing non-optional argument '{arg.name}' ({arg.typ}) at position {i}\")\n"
          buffer &= &"    else: params.{arg.name} = &{optTmp}\n"

  buffer &= &"\n  ok(ensureMove(params))"
  ensureMove(buffer)

proc main() {.inline.} =
  let
    args = parseInput()
    target = args.command
    dest = args.arguments[0]
    name = args.arguments[1]

  let parsed = parseSubsystem(readFile(target))
  if !parsed:
    let e = parsed.error()
    quit(&"Parse error: {e.msg} (at {e.pos})")

  writeFile(
    dest,
    generateWrapper(
      &parsed,
      name,
      target,
      isClient = args.enabled("client", "C"),
      dontGenerateFns = args.enabled("dont-generate-fns", "D"),
    ),
  )
  let nph = findExe("nph")

  if nph.len > 0:
    discard execCmd(&"{nph} {dest}")

when isMainModule:
  main()
