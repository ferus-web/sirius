## CSS parser implementation using Stylus
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, importutils, strformat]
import pkg/stylus/[parser, shared, tokenizer], pkg/[results, shakar]
import components/style/types

privateAccess(tokenizer.Tokenizer)

proc eof(parser: Parser): bool {.inline.} =
  parser.input.tokenizer.isEof

proc reconsume*(parser: Parser, state: ParserState) {.inline.} =
  parser.reset(state)

proc parseValueFromToken*(parser: Parser, token: Token): CSSValue =
  case token.kind
  of tkFunction:
    assert(false, "Nested CSS functions not supported yet")
  of tkDimension:
    let unit = parseUnit(token.unit)
    if *unit:
      return dimension(token.dValue, &unit)
    else:
      # FIXME: this is a bug in stylus. Numbers are marked as dimensions
      if !token.dIntVal:
        return decimal(token.dValue)
      else:
        return number(&token.dIntVal)
  of tkPercentage:
    return dimension(token.pUnitValue * 100, CSSUnit.Percent)
      # FIXME: for some weird reason, percentage tokens are divided by 100 in stylus?
  of tkIdent:
    return str(token.ident)
  of tkQuotedString:
    return str(token.qStr)
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
    args &= value

  parser.atStartOf = none(BlockType)
  some(function(name, move(args)))

proc parseRule*(parser: Parser): Option[Rule] =
  let ident = parser.expectIdent()
  if !ident:
    return

  if !parser.expectColon():
    return

  var values = CSSValue(kind: CSSValueKind.List)

  while not parser.eof:
    let value = &parser.next()

    case value.kind
    of tkFunction:
      values.list &= &parser.parseFunction(value)
    of tkDimension, tkIdent, tkPercentage, tkQuotedString:
      values.list &= parser.parseValueFromToken(value)
    else:
      discard

    if *parser.expectSemicolon():
      break

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

proc eatRules(parser: Parser, selector: Selector, rules: var Stylesheet) =
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

    var rule = &ruleOpt
    rule.selector = selector
    rules &= ensureMove(rule)

    checkEnd()

proc handleIdent(parser: Parser, token: Token): Stylesheet =
  if !parser.expectCurlyBracketBlock():
    return

  # echo token.ident & " {"

  var rules: Stylesheet
  let name = token.ident

  eatRules(parser, tagSelector(name), rules)
  ensureMove(rules)

proc handleDelim(parser: Parser, delim: char): Result[Stylesheet, string] =
  case delim
  of '*':
    var rules: Stylesheet
    eatRules(parser, universalSelector(), rules)

    return ok(ensureMove(rules))
  else:
    return err(&"Unhandled delimiter '{delim}'")

proc parseStylesheet*(parser: Parser): Stylesheet =
  var rules: Stylesheet

  while not parser.eof:
    let initTokenOpt = parser.next()
    if !initTokenOpt:
      continue

    let initToken = &initTokenOpt
    case initToken.kind
    of tkIdent:
      rules &= handleIdent(parser, initToken)
    of tkDelim:
      let rulesOpt = handleDelim(parser, initToken.delim)
      if !rulesOpt:
        continue

      rules &= &rulesOpt
    else:
      discard

  ensureMove(rules)

export newParser, newParserInput
