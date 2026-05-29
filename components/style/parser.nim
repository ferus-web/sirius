## CSS parser implementation using Stylus
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, importutils, strformat, strutils, sugar]
import pkg/stylus/[parser, shared, tokenizer], pkg/[results, shakar]
import components/style/types

privateAccess(tokenizer.Tokenizer)

proc eof(parser: Parser): bool {.inline.} =
  parser.input.tokenizer.isEof

proc clone*(src: Tokenizer): Tokenizer =
  if src == nil:
    return nil

  result = new(Tokenizer)
  result.input = src.input
  result.pos = src.pos
  result.currLineStartPos = src.currLineStartPos
  result.currLineNumber = src.currLineNumber
  result.varOrEnvFunctions = src.varOrEnvFunctions
  result.sourceMapUrl = src.sourceMapUrl
  result.sourceUrl = src.sourceUrl

proc clone*(src: ParserInput): ParserInput =
  if src == nil:
    return nil

  result = new(ParserInput)
  result.tokenizer = clone(src.tokenizer)
  result.cachedToken = src.cachedToken

proc reconsume*(parser: Parser, state: ParserState) {.inline.} =
  parser.reset(state)

proc parseValueFromToken*(parser: Parser, token: Token): Result[CSSValue, string] =
  case token.kind
  of tkFunction:
    return err("Nested CSS functions not supported yet")
  of tkDimension:
    let unit = parseUnit(token.unit)
    if *unit:
      return ok(dimension(token.dValue, &unit))
    else:
      # FIXME: this is a bug in stylus. Numbers are marked as dimensions
      if !token.dIntVal:
        return ok(decimal(token.dValue))
      else:
        return ok(number(&token.dIntVal))
  of tkPercentage:
    return ok(dimension(token.pUnitValue * 100, CSSUnit.Percent))
      # FIXME: for some weird reason, percentage tokens are divided by 100 in stylus?
  of tkIdent:
    return ok(str(token.ident))
  of tkQuotedString:
    return ok(str(token.qStr))
  of tkIDHash:
    return ok(hex(token.idHash))
  of tkHash:
    return ok(hex(token.hash))
  else:
    discard

proc parseFunction*(parser: Parser, nameTok: Token): Option[CSSValue] {.inline.} =
  let name = nameTok.fnName
  var args: seq[CSSValue]

  if !parser.expectParenBlock():
    return

  while not parser.eof:
    let next = &parser.next()
    if next.kind == tkComma:
      continue

    if next.kind == tkCloseParen:
      break

    let value = parser.parseValueFromToken(next)
    if *value:
      args &= &value

  parser.atStartOf = none(BlockType)
  some(function(name, move(args)))

proc parseRule*(parser: Parser): Option[Rule] =
  let startInput = parser.input.clone()

  let ident = parser.expectIdent()
  if !ident:
    parser.input = startInput
    return

  if !parser.expectColon():
    parser.input = startInput
    return

  var values = CSSValue(kind: CSSValueKind.List)

  while not parser.eof:
    let preNextInput = parser.input.clone()
    let valueOpt = parser.next()
    if !valueOpt:
      break

    let value = get valueOpt

    case value.kind
    of tkFunction:
      values.list &= get parser.parseFunction(value)
    of tkDimension, tkIdent, tkPercentage, tkQuotedString, tkIDHash, tkHash:
      let value = parser.parseValueFromToken(value)
      if *value:
        values.list &= get value
    of tkComma:
      discard
    # FIXME: Proper validation
    of tkDelim:
      discard
    of tkSemicolon:
      break
    of tkCloseCurlyBracket:
      # NOTE: We mustn't consume this. Revert back to the old state.
      parser.input = preNextInput
      break
    else:
      # assert off, $value.kind # & ' ' & $value.delim
      return none(Rule)

  return some(
    Rule(
      key: (&ident),
      value:
        if values.list.len == 1:
          values.list[0]
        else:
          ensureMove(values),
    )
  )

proc eatRules(parser: Parser, selectors: seq[Selector], rules: var Stylesheet) =
  template checkEnd() =
    let state = parser.input.clone()
    if *parser.expectCloseCurlyBracket:
      # If we encountered the end of the block,
      # we've parsed all the rules for this selector.
      break
    else:
      # Else, continue.
      parser.input = state

  while not parser.eof:
    checkEnd()

    let ruleOpt = parseRule(parser)
    if !ruleOpt:
      continue

    var rule = get ruleOpt
    rule.selectors = selectors
    rules &= ensureMove(rule)

    checkEnd()

proc parseSelector(parser: Parser, initial: Token): Option[Selector] =
  case initial.kind
  of tkIdent:
    # TODO: pseudoclasses
    return some(typeSelector(initial.ident))
  of tkDelim:
    case initial.delim
    of '*':
      return some(universalSelector())
    of '.':
      let next = parser.next()
      if !next:
        return # `.` must be followed by identifier

      return some(classSelector((&next).ident))
    of '#':
      let next = parser.next()
      if !next:
        return # `#` must be followed by identifier

      return some(idSelector((&next).ident))
    of '@':
      assert not true
    else:
      return # Unknown delimiter '{initial.delim}'
  else:
    return

proc parseSelectors(parser: Parser, initial: Token): seq[Selector] =
  var sels: seq[Selector]

  var token = initial
  while not parser.eof:
    let selector = parser.parseSelector(token)
    if !selector:
      break

    sels &= &selector

    let preNextInput = parser.input.clone()
    let tok = parser.next()
    if !tok:
      break

    token = &tok
    case token.kind
    of tkComma:
      continue
    of tkCurlyBracketBlock:
      parser.input = preNextInput
    else:
      discard

    break

  ensureMove(sels)

proc handleRuleset(parser: Parser, token: Token): Stylesheet =
  var rules: Stylesheet
  let selectors = parseSelectors(parser, initial = token)

  if !parser.expectCurlyBracketBlock():
    return

  eatRules(parser, selectors, rules)
  ensureMove(rules)

import pretty
proc parseStylesheet*(parser: Parser): Stylesheet =
  var rules: Stylesheet

  while not parser.eof:
    let token = parser.next()
    if !token:
      break

    rules &= handleRuleset(parser, &token)

  print rules

  ensureMove(rules)

export newParser, newParserInput
