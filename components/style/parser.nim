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
    return ok(dimension(token.pUnitValue, CSSUnit.Percent))
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

proc parseDeclaration*(parser: Parser): Option[Declaration] =
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
      return none(Declaration)

  return some(
    Declaration(
      key: (&ident),
      value:
        if values.list.len == 1:
          values.list[0]
        else:
          ensureMove(values),
    )
  )

proc eatDeclarations(parser: Parser, decls: var seq[Declaration]) =
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

    let declOpt = parseDeclaration(parser)
    if !declOpt:
      break

    decls &= &declOpt

    checkEnd()

proc parseMediaSelector(parser: Parser): Option[Selector] =
  # TODO: Maybe we should do real parsing.
  # But for now, this'll do. I just want to make sure the parser doesn't
  # deadlock or crash or just act badly here right now.

  while not parser.eof:
    let nextTok = parser.next()
    if !nextTok:
      break

    if (&nextTok).kind == tkCurlyBracketBlock:
      return some(idSelector("this-is-super-professional-engineering"))
        # HACK: yeah. I don't think I need to explain myself.

proc parseSelector(parser: Parser, initial: Token): Option[Selector] =
  case initial.kind
  of tkIdent:
    return some(typeSelector(initial.ident))
  of tkIDHash:
    # let next = parser.next()
    # if !next:
    #  return # `#` must be followed by identifier

    return some(idSelector(initial.idHash))
  of tkDelim:
    case initial.delim
    of '*':
      return some(universalSelector())
    of '.':
      let next = parser.next()
      if !next:
        return # `.` must be followed by identifier

      return some(classSelector((&next).ident))
    else:
      return # Unknown delimiter '{initial.delim}'
  of tkAtKeyword:
    if initial.at == "media":
      return parseMediaSelector(parser)
    else:
      return # Unknown at-rule '{initial.at}'
  else:
    return

proc parseSelectors*(parser: Parser, initial: Token): SelectorList =
  var sels: SelectorList
  var token = initial

  while not parser.eof:
    var complexSel: ComplexSelector

    while not parser.eof:
      var compSels: CompoundSelector

      while not parser.eof:
        let selector = parser.parseSelector(token)
        if !selector:
          break

        compSels &= &selector

        let preNextInput = parser.input.clone()
        let tok = parser.next()
        if !tok:
          break

        token = &tok

        if token.kind in {tkCurlyBracketBlock, tkComma, tkWhitespace} or
            (token.kind == tkDelim and token.delim in {'>', '+', '~'}):
          parser.input = preNextInput
          break
        else:
          discard

      if compSels.len == 0:
        break

      var nextCombinator = Combinator.Descendant
      var hitEnd = false
      var hasWhitespace = false

      var prePeekInput = parser.input.clone()
      var tok = parser.next()

      while *tok and (&tok).kind == tkWhitespace:
        hasWhitespace = true
        prePeekInput = parser.input.clone()
        tok = parser.next()

      if !tok:
        complexSel &= ComplexItem(selector: compSels, combinator: nextCombinator)
        break

      token = &tok

      case token.kind
      of tkCurlyBracketBlock, tkComma:
        hitEnd = true
        complexSel &= ComplexItem(selector: compSels, combinator: Combinator.Descendant)

        parser.input = prePeekInput
      of tkDelim:
        if token.delim in {'>', '~', '+'}:
          if token.delim == '>':
            nextCombinator = Combinator.Child
          elif token.delim == '+':
            nextCombinator = Combinator.Adjacent
          elif token.delim == '~':
            nextCombinator = Combinator.Sibling

          complexSel &= ComplexItem(selector: compSels, combinator: nextCombinator)

          var trailTok = parser.next()
          while *trailTok and (&trailTok).kind == tkWhitespace:
            trailTok = parser.next()

          if *trailTok:
            token = &trailTok
          else:
            break
        else:
          hitEnd = true
          complexSel &=
            ComplexItem(selector: compSels, combinator: Combinator.Descendant)
          parser.input = prePeekInput
      else:
        if hasWhitespace:
          complexSel &=
            ComplexItem(selector: compSels, combinator: Combinator.Descendant)
        else:
          hitEnd = true
          complexSel &=
            ComplexItem(selector: compSels, combinator: Combinator.Descendant)
          parser.input = prePeekInput

      if hitEnd:
        break

    if complexSel.len > 0:
      sels &= complexSel

    let preBoundaryInput = parser.input.clone()
    let tok = parser.next()
    if !tok:
      break
    token = &tok

    case token.kind
    of tkComma:
      var nextTok = parser.next()
      while *nextTok and (&nextTok).kind == tkWhitespace:
        nextTok = parser.next()
      if *nextTok:
        token = &nextTok
      continue
    else:
      parser.input = preBoundaryInput
      break

  return sels

proc handleRuleset(parser: Parser, token: Token): Option[Rule] =
  var rule: Rule

  let selectors = parseSelectors(parser, initial = token)

  if !parser.expectCurlyBracketBlock():
    return none(Rule)

  rule.selectors = selectors
  eatDeclarations(parser, rule.declarations)

  some(ensureMove(rule))

proc parseStylesheet*(parser: Parser): Stylesheet =
  var rules: Stylesheet

  while not parser.eof:
    let token = parser.next()
    if !token:
      break

    if (&token).kind in {tkWhitespace, tkComment}:
      continue

    let rule = handleRuleset(parser, &token)
    if !rule:
      break

    rules &= &rule

  ensureMove(rules)

export newParser, newParserInput
