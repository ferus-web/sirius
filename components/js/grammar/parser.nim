## JavaScript parser
##
## Copyright (C) 2024-2026 Trayambak Rai (xtrayambak@disroot.org)

import std/[options, strutils, strformat, tables, sequtils]
import components/js/grammar/[token, tokenizer, ast, errors, statement]
import components/js/runtime/vm/atom, components/aux/pretty
import pkg/[results, yaml, shakar]

{.push warning[UnreachableCode]: off.}

type
  ParserOpts* = object
    test262*: bool = false ## Whether to scan for Test262 directives

  TableParsingState* {.pure.} = enum
    Key
    Colon
    Value
    PostValue

  Parser* = ref object
    tokenizer*: Tokenizer
    ast: AST
    lines: seq[string]
    errors*: seq[ParseError]
    opts*: ParserOpts

    precededByMultilineComment: bool = false
    foundShebang: bool = false

template error(parser: Parser, errorKind: ParseErrorKind, msg: string) =
  # debugEcho instantiationInfo()
  parser.errors &=
    ParseError(kind: errorKind, location: parser.tokenizer.location, message: msg)

  return

func `$`*(error: ParseError): string =
  var buff: string

  case error.kind
  of UnexpectedToken:
    buff &= "unexpected token: " & error.message
  of Other:
    buff &= error.message

  buff & " (line " & $error.location.line & ", column " & $error.location.col & ')'

{.push gcsafe.}
proc parseArguments(parser: Parser): Option[PositionedArguments]

proc parseExpression(
  parser: Parser, storeIn: Option[string] = none(string), ignoreTerms: bool = false
): Option[Statement]

proc parseFunctionCall(parser: Parser, name: string): Option[Statement] =
  let
    args = parser.parseArguments()
    arguments =
      if *args:
        &args
      else:
        newSeq[CallArg](0)

  if name == "$DONOTEVALUATE":
    parser.ast.doNotEvaluate = true

  some(call(name.callFunction, arguments))

proc parsePostfixCall(parser: Parser, callTokens: seq[Token]): Option[Statement] =
  let
    accesses = callTokens
      .filterIt(it.kind == TokenKind.Identifier)
      .mapIt(it.ident)
      .createFieldAccess()

    args = parser.parseArguments()

  some(call(callFunction(accesses), args))

proc parseAtom(parser: Parser, token: Token): Option[Statement]

func getOperatorPrecedence(kind: TokenKind): uint8 {.inline.} =
  case kind
  of TokenKind.Or:
    1'u8
  of TokenKind.And:
    2'u8
  of TokenKind.Equal, TokenKind.NotEqual, TokenKind.TrueEqual:
    3'u8
  of TokenKind.LessThan, TokenKind.LessEqual, TokenKind.GreaterThan,
      TokenKind.GreaterEqual:
    4'u8
  of TokenKind.Add, TokenKind.Sub:
    5'u8
  of TokenKind.Mul, TokenKind.Div:
    6'u8
  else:
    0'u8

func tokenToBinOp(kind: TokenKind): BinaryOperation =
  case kind
  of TokenKind.Add: BinaryOperation.Add
  of TokenKind.Sub: BinaryOperation.Sub
  of TokenKind.Mul: BinaryOperation.Mult
  of TokenKind.Div: BinaryOperation.Div
  of TokenKind.Equal: BinaryOperation.Equal
  of TokenKind.TrueEqual: BinaryOperation.TrueEqual
  of TokenKind.GreaterThan: BinaryOperation.GreaterThan
  of TokenKind.GreaterEqual: BinaryOperation.GreaterOrEqual
  of TokenKind.LessThan: BinaryOperation.LesserThan
  of TokenKind.LessEqual: BinaryOperation.LesserOrEqual
  of TokenKind.NotEqual: BinaryOperation.NotEqual
  else: BinaryOperation.Invalid

proc finalizePostfixTokens(postfixTokens: seq[Token]): Option[Statement] =
  let idents = postfixTokens.filterIt(it.kind == TokenKind.Identifier).mapIt(it.ident)

  case idents.len
  of 0:
    none(Statement)
  of 1:
    some(identHolder(idents[0]))
  else:
    some(fieldHolder(createFieldAccess(idents)))

proc parsePrimary(parser: Parser): Option[Statement] =
  var postfixTokens = newSeqOfCap[Token](1) # NOTE: Again, prealloc?
  while not parser.tokenizer.eof:
    let
      savedPos = parser.tokenizer.pos
      savedLoc = parser.tokenizer.location
      next = parser.tokenizer.next()

    case next.kind
    of TokenKind.Whitespace, TokenKind.Comment:
      if next.kind == TokenKind.Whitespace and next.isNewline():
        parser.tokenizer.pos = savedPos
        parser.tokenizer.location = savedLoc
        if postfixTokens.len > 0:
          return finalizePostfixTokens(postfixTokens)
        return none(Statement)
      if postfixTokens.len > 0:
        let peekTok = parser.tokenizer.peekExceptWhitespace()
        if !peekTok or (&peekTok).kind notin {TokenKind.Dot, TokenKind.LParen}:
          return finalizePostfixTokens(postfixTokens)
    of TokenKind.Number:
      if postfixTokens.len > 0:
        parser.tokenizer.pos = savedPos
        parser.tokenizer.location = savedLoc
        return finalizePostfixTokens(postfixTokens)
      return parser.parseAtom(next)
    of TokenKind.String:
      if postfixTokens.len > 0:
        parser.tokenizer.pos = savedPos
        parser.tokenizer.location = savedLoc
        return finalizePostfixTokens(postfixTokens)
      if (let err = next.getError(); *err):
        parser.error Other, &err
      return parser.parseAtom(next)
    of TokenKind.True:
      if postfixTokens.len > 0:
        parser.tokenizer.pos = savedPos
        parser.tokenizer.location = savedLoc
        return finalizePostfixTokens(postfixTokens)
      return some(atomHolder(stackBoolean(true)))
    of TokenKind.False:
      if postfixTokens.len > 0:
        parser.tokenizer.pos = savedPos
        parser.tokenizer.location = savedLoc
        return finalizePostfixTokens(postfixTokens)
      return some(atomHolder(stackBoolean(false)))
    of TokenKind.Identifier:
      if postfixTokens.len > 0 and
          postfixTokens[postfixTokens.len - 1].kind == TokenKind.Identifier:
        parser.tokenizer.pos = savedPos
        parser.tokenizer.location = savedLoc
        return finalizePostfixTokens(postfixTokens)
      postfixTokens &= next
    of TokenKind.Dot:
      if postfixTokens.len == 0 or
          postfixTokens[postfixTokens.len - 1].kind != TokenKind.Identifier:
        parser.tokenizer.pos = savedPos
        parser.tokenizer.location = savedLoc
        return none(Statement)
      postfixTokens &= next
    of TokenKind.LParen:
      if postfixTokens.len > 0 and
          postfixTokens[postfixTokens.len - 1].kind == TokenKind.Identifier:
        if postfixTokens.len == 1:
          return parser.parseFunctionCall(postfixTokens[0].ident)
        else:
          return parsePostfixCall(parser, move(postfixTokens))
      else:
        let inner = parser.parseExpression(ignoreTerms = true)
        if !inner:
          return none(Statement)
        let closeTok = parser.tokenizer.nextExceptWhitespace()
        if !closeTok or (&closeTok).kind != TokenKind.RParen:
          parser.error Other, "expected closing parenthesis"

        return inner
    else:
      parser.tokenizer.pos = savedPos
      parser.tokenizer.location = savedLoc
      if postfixTokens.len > 0:
        return finalizePostfixTokens(postfixTokens)
      return none(Statement)

  if postfixTokens.len > 0:
    return finalizePostfixTokens(postfixTokens)

  return none(Statement)

proc parseBinaryExpr(parser: Parser, minPrec: uint8): Option[Statement] =
  var lhsOpt = parser.parsePrimary()
  if !lhsOpt:
    return none(Statement)

  var lhs = &lhsOpt
  while not parser.tokenizer.eof:
    let
      savedPos = parser.tokenizer.pos
      savedLoc = parser.tokenizer.location
    var
      hitNewline = false
      opTokOpt = none(Token)

    while not parser.tokenizer.eof:
      let tok = parser.tokenizer.next()
      case tok.kind
      of TokenKind.Whitespace:
        if tok.isNewline():
          hitNewline = true
          break
      of TokenKind.Comment:
        discard
      else:
        opTokOpt = some(tok)
        break

    if hitNewline or !opTokOpt:
      parser.tokenizer.pos = savedPos
      parser.tokenizer.location = savedLoc
      break

    let opTok = &opTokOpt
    let prec = getOperatorPrecedence(opTok.kind)
    if prec < minPrec:
      parser.tokenizer.pos = savedPos
      parser.tokenizer.location = savedLoc
      break

    let rhsOpt = parser.parseBinaryExpr(prec + 1)
    if !rhsOpt:
      parser.error Other, &"expected valid expression after {opTok.kind}"
      return none(Statement)

    lhs = Statement(
      kind: BinaryOp, op: tokenToBinOp(opTok.kind), binLeft: lhs, binRight: &rhsOpt
    )

  return some(lhs)

proc parseExpression(
    parser: Parser, storeIn: Option[string] = none(string), ignoreTerms: bool = false
): Option[Statement] =
  let res = parser.parseBinaryExpr(1'u8)
  if !res:
    return none(Statement)

  var node = &res
  if node.kind == BinaryOp:
    node.binStoreIn = storeIn

  if ignoreTerms:
    return some(node)

  if node.kind == BinaryOp and node.binLeft != nil and node.binRight != nil:
    return some(node)

  return none(Statement)

proc parseConstructor(parser: Parser): Option[Statement] =
  let next = parser.tokenizer.nextExceptWhitespace()

  if !next:
    parser.error UnexpectedToken, "expected Identifier, got EOF"

  if (&next).kind != TokenKind.Identifier:
    parser.error UnexpectedToken, "expected Identifier, got " & $(&next).kind

  if parser.tokenizer.eof or parser.tokenizer.next().kind != TokenKind.LParen:
    return some(constructObject((&next).ident, @[]))

  let arguments = parser.parseArguments()
  if !arguments:
    parser.error Other, "expected arguments for constructor after type name"

  return some(constructObject((&next).ident, &arguments))

proc parseTypeofCall(parser: Parser): Option[PositionedArguments] =
  if parser.tokenizer.eof:
    parser.error Other, "expected expression, got EOF"

  let
    tokenizer = parser.tokenizer
    next = parser.tokenizer.nextExceptWhitespace()
    mustEndWithParen = *next and (&next).kind == TokenKind.LParen

  var metParen = false

  if not mustEndWithParen:
    parser.tokenizer = tokenizer

  var args: PositionedArguments
  while not parser.tokenizer.eof:
    if mustEndWithParen and metParen:
      break

    let token = parser.tokenizer.next()

    if token.isNewline():
      break

    if token.kind == TokenKind.Whitespace:
      continue

    if token.kind == TokenKind.RParen:
      metParen = true
      break

    if token.kind == TokenKind.Identifier:
      var idents = @[token.ident]
      while not parser.tokenizer.eof:
        let saved = parser.tokenizer
        let peekTok = parser.tokenizer.nextExceptWhitespace()
        if *peekTok and (&peekTok).kind == TokenKind.Dot:
          let nextIdent = parser.tokenizer.nextExceptWhitespace()
          if *nextIdent and (&nextIdent).kind == TokenKind.Identifier:
            idents &= (&nextIdent).ident
          else:
            parser.error UnexpectedToken, "expected identifier after dot"
        else:
          parser.tokenizer = saved
          break

      if idents.len > 1:
        args.pushFieldAccess(createFieldAccess(idents))
      else:
        args.pushIdent(token.ident)
    else:
      let atom = parser.parseAtom(token)
      if !atom:
        parser.error UnexpectedToken, "expected value or identifier, got " & $token.kind

      args.pushImmExpr(&atom)

  if mustEndWithParen and not metParen:
    parser.error Other, "missing ) in parenthetical"

  some(args)

proc parseFunction(
  parser: Parser, name: Option[string] = none(string)
): Option[Function]

proc parseTable(parser: Parser): Option[KeyValuePairs] =
  if parser.tokenizer.eof:
    parser.error Other, "expected expression, got EOF"

  var
    table: KeyValuePairs
    currentKey: Statement

    metRCurly = false
    state = TableParsingState.Key

  while not parser.tokenizer.eof and not metRCurly:
    let token = parser.tokenizer.next()

    case state
    of TableParsingState.Key:
      let key =
        case token.kind
        of TokenKind.Identifier:
          atomHolder(stackStr(token.ident))
        of TokenKind.String:
          atomHolder(stackStr(token.str))
        of TokenKind.Number:
          &parser.parseAtom(token)
        of TokenKind.RCurly:
          metRCurly = true
          break
        of TokenKind.Whitespace:
          continue
        else:
          parser.error UnexpectedToken, &"{token.kind} (expected identifier or string)"

      table[key] = atomHolder(stackNull())
      currentKey = key
      state = TableParsingState.Colon
    of TableParsingState.Colon:
      case token.kind
      of TokenKind.Colon:
        state = TableParsingState.Value
      of TokenKind.Whitespace:
        discard
      else:
        parser.error Other,
          "expected Colon or right-brace after property id, got " & $token.kind &
            " instead"
    of TableParsingState.Value:
      case token.kind
      of TokenKind.Identifier:
        parser.error Other, "identifiers are not supported in maps yet"
      of TokenKind.Whitespace:
        discard
      of TokenKind.Function:
        let fn = parser.parseFunction(name = some(newString(0)))
        if !fn:
          parser.error UnexpectedToken, &"expected body after `function`"

        table[currentKey] = functionHolder(&fn)
        state = TableParsingState.PostValue
      else:
        let atom = parser.parseAtom(token)
        if !atom:
          parser.error UnexpectedToken, &"expected value, got {token.kind}"

        table[currentKey] = &atom
        state = TableParsingState.PostValue
    of TableParsingState.PostValue:
      case token.kind
      of TokenKind.RCurly:
        metRCurly = true
        break # we've hit our }, end table parsing
      of TokenKind.Comma:
        state = TableParsingState.Key # a new key-value pair is ahead, continue
      of TokenKind.Whitespace:
        # Ignore whitespace.
        continue
      else:
        parser.error UnexpectedToken,
          &"{token.kind} (expected right-curly-bracket or comma)"

  if not metRCurly:
    parser.error Other, "property list must be ended by }"

  some(ensureMove(table))

proc parseArray(parser: Parser): Option[Statement] =
  if parser.tokenizer.eof:
    parser.error Other, "expected expression, got EOF"

  var
    arr: MixedLiteralChildren
    prev = TokenKind.LBracket
    metRBracket = false

  while not parser.tokenizer.eof and not metRBracket:
    let token = parser.tokenizer.next()
    if token.kind == TokenKind.Whitespace:
      continue

    if token.kind == TokenKind.RBracket:
      metRBracket = true
      break

    if token.kind == TokenKind.Comma:
      if prev in {TokenKind.LBracket, TokenKind.Comma}:
        prev = TokenKind.Comma
        arr &= atomHolder(stackUndefined())
      else:
        prev = TokenKind.Comma

      continue

    if token.kind == TokenKind.Comment:
      continue

    if token.kind == TokenKind.Identifier:
      arr &= identHolder(token.ident)
    else:
      let atom = parser.parseAtom(token)
      if !atom:
        parser.error UnexpectedToken,
          "expected expression, value or name, got " & $token.kind & " instead."

      arr &= &atom

    # Just a check to see if the next token is valid.
    # From valid, according to the grammar rules, it can only be two tokens:
    # `,` and `]` to add another element and to close off the parsing algorithm
    # respectively.
    var copiedTok = parser.tokenizer
    while not parser.tokenizer.eof:
      if (let tok = parser.tokenizer.nextExceptWhitespace(); *tok):
        let kind = (&tok).kind
        if kind == TokenKind.Comment:
          continue

        if kind notin {TokenKind.Comma, TokenKind.RBracket}:
          parser.error UnexpectedToken,
            "expected comma (,) or right bracket (]) after array element, got " & $kind
        else:
          parser.tokenizer = ensureMove(copiedTok)
          break
      else:
        parser.error Other, "missing ] after element list"

    prev = token.kind

  if not metRBracket:
    parser.error Other, "array is not closed off by bracket"

  some createArrayLiteral(arr)

proc parseArrayIndex(parser: Parser, ident: string): Option[Statement] =
  if parser.tokenizer.eof:
    parser.error Other, "expected expression, got EOF"

  template missingRBracket() =
    parser.error Other, "missing ] in index expression"
    return false

  proc checkForRBracket(): bool =
    let closing = parser.tokenizer.nextExceptWhitespace()
    if !closing:
      missingRBracket

    let kind = (&closing).kind
    case kind
    of TokenKind.RBracket:
      return true
    of TokenKind.Comment:
      return checkForRBracket()
    else:
      missingRBracket

  if (let indexToken = parser.tokenizer.nextExceptWhitespace(); *indexToken):
    let
      token = &indexToken
      cTok = parser.tokenizer
      atom = parser.parseAtom(token)

    if !atom:
      parser.tokenizer = cTok
    else:
      if checkForRBracket():
        return some(arrayAccess(ident, &atom))

    if not checkForRBracket():
      return

    case token.kind
    of TokenKind.Identifier:
      return some(arrayAccess(ident, token.ident))
    else:
      parser.error UnexpectedToken, "expected identifier or numeric, got " & $token.kind
  else:
    parser.error Other, "expected expression, got EOF"

proc expectEqualsSign(
    parser: Parser, stubDef: proc(): Result[Option[Statement], void] {.gcsafe.}
): Result[Option[Statement], void] =
  let nextTok = parser.tokenizer.next()
  case nextTok.kind
  of TokenKind.Semicolon:
    return stubDef()
  of TokenKind.EqualSign:
    return ok(none(Statement))
  of TokenKind.Whitespace:
    if isNewline(nextTok):
      return stubDef()
    else:
      expectEqualsSign parser, stubDef
  else:
    parser.error UnexpectedToken,
      "expected semicolon or equal sign after identifier, got " & $nextTok.kind

proc parseTernaryOp(
  parser: Parser,
  ident: Option[string] = none(string),
  atom: Option[MAtom] = none(MAtom),
  condStmt: Option[Statement] = none(Statement),
): Option[Statement]

proc parseTernaryBranch(parser: Parser): Option[Statement] =
  let res = parser.parseExpression(ignoreTerms = true)
  if !res:
    return none(Statement)

  var node = &res
  if not parser.tokenizer.eof:
    let
      savedPos = parser.tokenizer.pos
      savedLoc = parser.tokenizer.location
      nextTok = parser.tokenizer.nextExceptWhitespace()

    if *nextTok and (&nextTok).kind == TokenKind.Question:
      let nested = parser.parseTernaryOp(condStmt = some(node))
      if !nested:
        return none(Statement)
      node = &nested
    else:
      parser.tokenizer.pos = savedPos
      parser.tokenizer.location = savedLoc

  some(node)

proc parseTernaryOp(
    parser: Parser,
    ident: Option[string] = none(string),
    atom: Option[MAtom] = none(MAtom),
    condStmt: Option[Statement] = none(Statement),
): Option[Statement] =
  assert(
    *ident or *atom or *condStmt,
    "BUG: Expected initial `ident`, `atom`, or `condStmt` when parsing ternary operation, got none?",
  )
  var tern = Statement(kind: TernaryOp)
  tern.ternaryCond =
    if *condStmt:
      &condStmt
    elif *ident:
      identHolder(&ident)
    elif *atom:
      atomHolder(&atom)
    else:
      unreachable
      atomHolder(stackNull())

  let trueBranch = parser.parseTernaryBranch()
  if !trueBranch:
    parser.error UnexpectedToken, "expected valid expression in ternary true branch"
  tern.trueTernary = &trueBranch

  let expectColon = parser.tokenizer.nextExceptWhitespace()
  if !expectColon or (&expectColon).kind != TokenKind.Colon:
    parser.error Other, "missing `:` in ternary expression"

  let falseBranch = parser.parseTernaryBranch()
  if !falseBranch:
    parser.error UnexpectedToken, "expected valid expression in ternary false branch"
  tern.falseTernary = &falseBranch

  some(tern)

proc parseDeclaration(
    parser: Parser, initialIdent: string, reassignment: bool = false
): Option[Statement] =
  var ident = initialIdent

  if not reassignment:
    while not parser.tokenizer.eof:
      let tok = &parser.tokenizer.nextExceptWhitespace()

      case tok.kind
      of TokenKind.Identifier:
        ident = tok.ident
        break
      of TokenKind.EqualSign:
        break
      of TokenKind.Whitespace:
        continue
      of TokenKind.Number:
        parser.error UnexpectedToken, "numeric literal"
      else:
        parser.error UnexpectedToken,
          "expected identifier, equal-sign or numeric literal, got " & $tok.kind &
            " instead"

  proc stubDef(): Result[Option[Statement], void] =
    ok(some(decl(ident, atomHolder(stackUndefined()))))

  if parser.tokenizer.eof():
    if ident == initialIdent:
      parser.error Other, "identifier not defined"
    else:
      return &stubDef()

    unreachable

  let gotEquals = parser.expectEqualsSign(stubDef)
  if *gotEquals:
    if *(&gotEquals):
      return &gotEquals
    else:
      discard
  else:
    return

  let
    copiedTok = parser.tokenizer
    exprOpt = parser.parseExpression(ident.some())

  if !exprOpt:
    parser.tokenizer = copiedTok
  else:
    let expr = &exprOpt
    expr.storeIn = some(ident)
    return some(expr)

  var
    atom: Option[MAtom]
    vIdent: Option[string]
    vFieldAccess: Option[FieldAccess]
    ternary: Option[Statement]
    toCall: Option[Statement]
    declareFn: Option[Function]
    keyValuePair: Option[Table[Statement, Statement]]

    postfixMode = false
    postfixTokens = newSeqOfCap[Token](1)

  while not parser.tokenizer.eof and !vIdent and !atom and !toCall and !vFieldAccess:
    let tok = parser.tokenizer.next()

    case tok.kind
    of TokenKind.String:
      if (let err = tok.getError(); *err):
        parser.error Other, &err

      atom = some(stackStr tok.str)
      break
    of TokenKind.Identifier:
      postfixTokens &= tok
      while not parser.tokenizer.eof():
        let saved = parser.tokenizer
        let next = parser.tokenizer.nextExceptWhitespace()
        if !next:
          break

        case (&next).kind
        of TokenKind.LParen:
          if postfixMode:
            toCall = parser.parsePostfixCall(move(postfixTokens))
          else:
            toCall = parser.parseFunctionCall(tok.ident)
          break
        of TokenKind.LBracket:
          toCall = parser.parseArrayIndex(tok.ident)
          break
        of TokenKind.Question:
          if postfixMode:
            let fa = postfixTokens
              .filterIt(it.kind == TokenKind.Identifier)
              .mapIt(it.ident)
              .createFieldAccess()
            ternary = parser.parseTernaryOp(condStmt = some(fieldHolder(fa)))
          else:
            ternary = parser.parseTernaryOp(ident = some(tok.ident))
          break
        of TokenKind.Dot:
          postfixTokens &= &next
          postfixMode = true
          let nextIdent = parser.tokenizer.nextExceptWhitespace()
          if *nextIdent and (&nextIdent).kind == TokenKind.Identifier:
            postfixTokens &= &nextIdent
          else:
            parser.error UnexpectedToken, "expected identifier after dot"
        of TokenKind.Semicolon:
          if postfixMode:
            vFieldAccess = postfixTokens
              .filterIt(it.kind == TokenKind.Identifier)
              .mapIt(it.ident)
              .createFieldAccess()
              .some()
          else:
            vIdent = some(tok.ident)
          break
        else:
          parser.tokenizer = saved
          if postfixMode:
            vFieldAccess = postfixTokens
              .filterIt(it.kind == TokenKind.Identifier)
              .mapIt(it.ident)
              .createFieldAccess()
              .some()
          else:
            vIdent = some(tok.ident)
          break

      if !toCall and !ternary and !vFieldAccess and !vIdent:
        if postfixMode:
          vFieldAccess = postfixTokens
            .filterIt(it.kind == TokenKind.Identifier)
            .mapIt(it.ident)
            .createFieldAccess()
            .some()
        else:
          vIdent = some(tok.ident)
      break
    of TokenKind.Number:
      if *tok.intVal:
        atom = some(stackInteger(&tok.intVal))
      else:
        atom = some(stackFloating(tok.floatVal))
    of TokenKind.Whitespace:
      discard
    of TokenKind.True:
      atom = some(stackBoolean(true))
    of TokenKind.False:
      atom = some(stackBoolean(false))
    of TokenKind.New:
      toCall = parser.parseConstructor()
      break
    of TokenKind.Typeof:
      let typeofCall = parser.parseTypeofCall()
      if !typeofCall:
        parser.error Other, "invalid usage of typeof"

      toCall = some(call("BALI_TYPEOF".callFunction(), &typeofCall, mangle = false))
      break
    of TokenKind.LBracket:
      ternary = parser.parseArray()
      break
    of TokenKind.LCurly:
      keyValuePair = parser.parseTable()
      break
    of TokenKind.Function:
      let fn = parser.parseFunction(name = some(ident))
      declareFn = fn
    of TokenKind.Semicolon:
      if (
        !atom and !vIdent and !toCall and !ternary and !declareFn and !vFieldAccess and
        !keyValuePair
      ):
        parser.error UnexpectedToken, "expected value, got semicolon instead"

      break
    else:
      parser.error UnexpectedToken, $tok.kind

  if not (
    *atom or *vIdent or *toCall or *ternary or *declareFn or *vFieldAccess or
    *keyValuePair
  ):
    parser.error Other, "cannot parse literal or identifier"

  if *ternary:
    ternary.applyThis:
      this.storeIn = some(ident)
    return ternary

  if *declareFn:
    return
      some(defineFunction(&declareFn, some(parser.ast.scopes[parser.ast.currentScope])))

  if *keyValuePair:
    return some(constructObjectShort(ident, &keyValuePair))

  if *atom:
    return some(decl(ident, atomHolder(&atom)))
  elif *vIdent:
    return some(decl(ident, identHolder(&vIdent)))
  elif *toCall:
    return some(decl(ident, &toCall))
  elif *vFieldAccess:
    return some(decl(ident, fieldHolder(&vFieldAccess)))

proc parseStatement(parser: Parser): Option[Statement]

proc parseFunction(
    parser: Parser, name: Option[string] = none(string)
): Option[Function] =
  let nameOpt = name
  var name: Option[string]

  var prevTokenizer = parser.tokenizer
  while not parser.tokenizer.eof:
    let tok = parser.tokenizer.next()
    case tok.kind
    of TokenKind.Identifier:
      name = some(tok.ident)
    of TokenKind.Whitespace:
      continue
    else:
      discard

    break

  if !name and *nameOpt:
    name = nameOpt
    parser.tokenizer = ensureMove(prevTokenizer)

  if not *name:
    parser.error Other, "function statement requires a name"

  var
    metLParen = false
    metRParen = false
    arguments: seq[string]

  var last: Option[TokenKind]
  while not parser.tokenizer.eof:
    let tok = parser.tokenizer.next()

    case tok.kind
    of TokenKind.LParen:
      metLParen = true
      last = some(TokenKind.LParen)
      continue
    of TokenKind.RParen:
      metRParen = true

      if not metLParen:
        parser.error Other, "missing ( before formal parameters"

      last = some(TokenKind.RParen)
    of TokenKind.LCurly:
      if not metLParen:
        parser.error Other, "missing ( before start of function scope"

      if not metRParen:
        parser.error Other, "missing ) before start of function scope"

      break
    of TokenKind.Whitespace:
      last = some(TokenKind.Whitespace)
    of TokenKind.Identifier:
      if metRParen:
        parser.error Other, "unexpected identifier after end of function signature"

      # If the identifier is not preceded by:
      # - Commas
      # - Whitespace
      # - Left parenthesis
      # Then raise a parsing error
      # Example of erroneous sample this will catch:
      # function x(a b c) { }
      #            ^^^^^ It should be (a, b, c)
      if *last and &last notin {TokenKind.Comma, TokenKind.Whitespace, TokenKind.LParen}:
        parser.error Other, "unexpected identifier after " & $(&last)

      arguments &= tok.ident
      last = some(TokenKind.Identifier)
    of TokenKind.Comma:
      if !last:
        parser.error Other, "expected identifier for parameter name, got comma instead."

      if &last == TokenKind.Comma:
        parser.error UnexpectedToken, "expected identifier, got Comma instead"

      last = some(TokenKind.Comma)
    else:
      print tok
      discard

  var body: seq[Statement]
  var metRCurly = false
  while not parser.tokenizer.eof:
    let
      prevPos = parser.tokenizer.pos
      prevLoc = parser.tokenizer.location
      c = parser.tokenizer.nextExceptWhitespace()

    if *c and (&c).kind == TokenKind.RCurly:
      metRCurly = true
      break
    else:
      parser.tokenizer.pos = prevPos
      parser.tokenizer.location = prevLoc

    let stmt = parser.parseStatement()
    if not *stmt:
      continue

    var statement = &stmt
    statement.line = parser.tokenizer.location.line
    statement.col = parser.tokenizer.location.col

    body &= statement

  if not metRCurly:
    parser.error Other, "function body must end with curly bracket"

  some function(&name, body, arguments)

proc parseAtom(parser: Parser, token: Token): Option[Statement] =
  case token.kind
  of TokenKind.Number:
    return some atomHolder(stackFloating(token.floatVal))
  of TokenKind.String:
    if (let err = token.getError(); *err):
      parser.error Other, &err

    return some atomHolder stackStr(token.str)
  of TokenKind.True:
    return some atomHolder stackBoolean(true)
  of TokenKind.False:
    return some atomHolder stackBoolean(false)
  of TokenKind.LBracket:
    return parser.parseArray()
  else:
    return

proc parseArguments(parser: Parser): Option[PositionedArguments] =
  var
    metEnd = false
    args: PositionedArguments
    idx = -1
    last: Option[TokenKind]
    lastData: Option[Token]

  while not parser.tokenizer.eof and not metEnd:
    inc idx
    let copiedTok = parser.tokenizer

    if (let expr = parser.parseExpression(); *expr):
      args.pushImmExpr(&expr)
      continue
    else:
      parser.tokenizer = copiedTok

    let token = parser.tokenizer.next()

    case token.kind
    of TokenKind.Whitespace:
      discard
    of TokenKind.Comma:
      if *last and &last == TokenKind.Comma:
        parser.error UnexpectedToken,
          "expected identifier, value or right parenthesis after comma, got another comma instead."

      last = some(TokenKind.Comma)
    of TokenKind.Identifier:
      last = some(TokenKind.Identifier)
      lastData = some(token)
      var postfixTokens = @[token]
      var handled = false

      while not parser.tokenizer.eof:
        let
          prevPos = parser.tokenizer.pos
          prevLocation = parser.tokenizer.location
          nextTok = parser.tokenizer.nextExceptWhitespace()

        if !nextTok:
          break

        case (&nextTok).kind
        of TokenKind.Dot:
          postfixTokens &= &nextTok
          let nextIdent = parser.tokenizer.nextExceptWhitespace()
          if *nextIdent and (&nextIdent).kind == TokenKind.Identifier:
            postfixTokens &= &nextIdent
            lastData = nextIdent
          else:
            parser.error Other, "expected name after . operator"
        of TokenKind.LParen:
          let
            call =
              if postfixTokens.len > 1:
                parser.parsePostfixCall(move(postfixTokens))
              else:
                parser.parseFunctionCall(token.ident)
            resIdent = "@0_" & $idx

          if not parser.tokenizer.eof and (
            let afterTok = parser.tokenizer.peekExceptWhitespace()
            *afterTok and
              (&afterTok).kind in
              {TokenKind.Add, TokenKind.Sub, TokenKind.Mul, TokenKind.Div}
          ):
            let exprOpt = parser.parseExpression(ignoreTerms = true)
            if !exprOpt:
              parser.error Other, "expected expression after symbol, got none."

            let expr = &exprOpt
            expr.binRight = expr.binLeft
            expr.binLeft = &call

            args.pushImmExpr(expr)
          else:
            parser.ast.appendToCurrentScope(callAndStore(resIdent, &call))
            args.pushIdent(resIdent)
          handled = true
          break
        else:
          parser.tokenizer.pos = prevPos
          parser.tokenizer.location = prevLocation
          break

      if not handled:
        let idents =
          postfixTokens.filterIt(it.kind == TokenKind.Identifier).mapIt(it.ident)
        if idents.len > 1:
          args.pushFieldAccess(createFieldAccess(idents))
        else:
          args.pushIdent(token.ident)
    of TokenKind.Number, TokenKind.String:
      last = some(token.kind)
      let atom = parser.parseAtom(token)

      if !atom:
        parser.error Other, "expected atom, got malformed data instead."

      args.pushImmExpr(&atom)
    of TokenKind.True:
      last = some(TokenKind.True)
      args.pushAtom(stackBoolean(true))
    of TokenKind.False:
      last = some(TokenKind.False)
      args.pushAtom(stackBoolean(false))
    of TokenKind.RParen:
      last = some(TokenKind.RParen)
      metEnd = true
    of TokenKind.New:
      last = some(TokenKind.New)
      let
        call = parser.parseConstructor()
        resIdent = "@0_" & $idx

      parser.ast.appendToCurrentScope(callAndStore(resIdent, &call))
      args.pushIdent(resIdent)
    of TokenKind.LBracket:
      if !last or &last != TokenKind.Identifier:
        let arr = parser.parseArray()
        if !arr:
          parser.error Other, "got malformed array while parsing arguments"

        last = some(TokenKind.LBracket)
        args.pushImmExpr(&arr)
      else:
        let access = parser.parseArrayIndex((&lastData).ident)
        if !access:
          parser.error Other, "got malformed array indexing while parsing arguments"

        last = some(TokenKind.LBracket)
        discard args.pop()
        args.pushImmExpr(&access)
    of TokenKind.Function:
      if token.containsUnicodeEsc:
        parser.error Other, "keyword `function` cannot contain unicode escape(s)"

      let fnOpt = parser.parseFunction(name = some(newString(0)))

      if !fnOpt:
        parser.error Other, "unexpected end of input"

      args.pushImmExpr(defineFunction(&fnOpt, limitedTo = none(Scope)))
    else:
      parser.error UnexpectedToken, $token.kind

  if not metEnd:
    parser.error Other, "missing ) after argument list."

  some args

proc parseThrow(parser: Parser): Option[Statement] =
  var
    throwStr: Option[string]
    throwIdent: Option[string]
    throwErr: Option[void]

  while not parser.tokenizer.eof:
    let next = parser.tokenizer.next()

    if next.kind == TokenKind.Whitespace and next.isNewline():
      parser.error UnexpectedToken,
        "no line break is allowed between 'throw' and its expression"

    if next.kind == TokenKind.String:
      throwStr = some(next.str)
      break

    if next.kind == TokenKind.Identifier:
      throwIdent = some(next.ident)
      break

  if !throwStr and !throwErr and !throwIdent:
    parser.error Other, "throw statement is missing an expression"

  var stmt = throwError(throwStr, throwErr, throwIdent)
  stmt.source = parser.lines[parser.tokenizer.location.line]

  some(ensureMove(stmt))

proc parseReassignment(parser: Parser, ident: string): Option[Statement] =
  var expr: Option[Statement]

  if not parser.tokenizer.eof:
    let copiedTok = parser.tokenizer
    expr = parser.parseExpression()

    if !expr:
      parser.tokenizer = copiedTok
    else:
      expr.applyThis:
        this.binStoreIn = some(ident)
        this.source = parser.lines[copiedTok.location.line]

      return expr

  var
    atom: Option[Statement]
    vIdent: Option[string]
    vFieldAccess: Option[FieldAccess]
    toCall: Option[Statement]

  while not parser.tokenizer.eof and !vIdent and !atom and !toCall and !vFieldAccess:
    let tok = parser.tokenizer.next()

    case tok.kind
    of TokenKind.String, TokenKind.Number, TokenKind.Null:
      atom = parser.parseAtom(tok)
    of TokenKind.Identifier:
      var postfixTokens = @[tok]
      var isCall = false
      while not parser.tokenizer.eof():
        let copied = parser.tokenizer
        let next = parser.tokenizer.nextExceptWhitespace()
        if !next:
          break
        case (&next).kind
        of TokenKind.LParen:
          if postfixTokens.len > 1:
            toCall = parser.parsePostfixCall(move(postfixTokens))
          else:
            toCall = parser.parseFunctionCall(tok.ident)
          isCall = true
          break
        of TokenKind.Dot:
          postfixTokens &= &next
          let nextIdent = parser.tokenizer.nextExceptWhitespace()
          if *nextIdent and (&nextIdent).kind == TokenKind.Identifier:
            postfixTokens &= &nextIdent
          else:
            parser.error UnexpectedToken, "expected identifier after dot"
        else:
          parser.tokenizer = copied
          break

      if not isCall:
        let idents =
          postfixTokens.filterIt(it.kind == TokenKind.Identifier).mapIt(it.ident)
        if idents.len > 1:
          vFieldAccess = some(createFieldAccess(idents))
        else:
          vIdent = some(tok.ident)
      break
    of TokenKind.Whitespace:
      discard
    of TokenKind.New:
      let next = parser.tokenizer.nextExceptWhitespace()

      if !next:
        parser.error UnexpectedToken, "expected Identifier, got EOF"

      if (&next).kind != TokenKind.Identifier:
        parser.error UnexpectedToken, "expected Identifier, got " & $(&next).kind

      if not parser.tokenizer.eof() and parser.tokenizer.next().kind != TokenKind.LParen:
        parser.error Other, "expected left parenthesis when creating object constructor"

      let arguments = parser.parseArguments()
      if !arguments:
        parser.error Other, "expected arguments for constructor after type name"

      toCall = some(constructObject((&next).ident, &arguments))
      break
    else:
      parser.error UnexpectedToken, $tok.kind

  if *atom:
    var reassignExpr = reassignVal(ident, (&atom).atom)
    reassignExpr.source = parser.lines[parser.tokenizer.location.line]

    return some(ensureMove(reassignExpr))
  elif *vFieldAccess:
    if ident.contains('.'):
      return some(copyFieldToVar(createFieldAccess(ident.split('.')), &vFieldAccess))
    else:
      return some(copyFieldToVar(ident, &vFieldAccess))
  elif *vIdent:
    let identifier = &vIdent

    if identifier.contains('.'):
      if ident.contains('.'):
        return some(
          copyFieldToVar(
            createFieldAccess(ident.split('.')),
            createFieldAccess(identifier.split('.')),
          )
        )
      else:
        return some(copyFieldToVar(ident, createFieldAccess(identifier.split('.'))))
    else:
      var copyExpr = copyValMut(ident, identifier)
      copyExpr.source = parser.lines[parser.tokenizer.location.line]

      return some(ensureMove(copyExpr))
  elif *toCall:
    var callStoreExpr = callAndStore(ident, &toCall)
    callStoreExpr.source = parser.lines[parser.tokenizer.location.line]

    return some(ensureMove(callStoreExpr))

proc parseScope(parser: Parser): seq[Statement] =
  if parser.tokenizer.eof:
    parser.error Other, "expected left curly bracket, got EOF instead"

  let ephTok = parser.tokenizer
  var singleExpr = false
  if (let tok = parser.tokenizer.nextExceptWhitespace(); *tok):
    if (&tok).kind != TokenKind.LCurly:
      singleExpr = true
      parser.tokenizer = ephTok

  inc parser.ast.currentScope
  parser.ast.scopes.setLen(parser.ast.currentScope + 1)
  parser.ast.scopes[parser.ast.currentScope] = Scope()
  var stmts: seq[Statement]
  var metRCurly = false

  while not parser.tokenizer.eof:
    if not singleExpr:
      let c = parser.tokenizer.peekExceptWhitespace()

      if *c and (&c).kind == TokenKind.RCurly:
        metRCurly = true
        discard parser.tokenizer.nextExceptWhitespace()
        break

    let stmt = parser.parseStatement()

    if not *stmt:
      continue

    var statement = &stmt
    statement.line = parser.tokenizer.location.line
    statement.col = parser.tokenizer.location.col
    statement.source = parser.lines[parser.tokenizer.location.line]

    stmts &= statement

    if singleExpr:
      break

  dec parser.ast.currentScope

  if not metRCurly and not singleExpr:
    parser.error Other, "scope body must end with curly bracket"

  stmts

proc parseExprInParenWrap(
    parser: Parser, token: TokenKind, compounding: bool = false
): Option[Statement] =
  if parser.tokenizer.eof:
    parser.error Other, "expected conditions after control-flow token, got EOF instead"

  if not compounding and (let tok = parser.tokenizer.nextExceptWhitespace(); *tok):
    if (&tok).kind != TokenKind.LParen:
      parser.error Other, &"expected left parenthesis after {token} token"

  let copiedTok = parser.tokenizer
  var expr = parser.parseExpression()
  if !expr:
    let copiedTokPhase2 = parser.tokenizer
    parser.tokenizer = copiedTok

    let
      firstTok = parser.tokenizer.nextExceptWhitespace()
      atom =
        if *firstTok:
          if (&firstTok).kind == TokenKind.Identifier:
            some(identHolder((&firstTok).ident))
          else:
            parser.parseAtom(&firstTok)
        else:
          none(Statement)

    if !atom:
      parser.tokenizer = copiedTokPhase2
      parser.error Other, "expected expression, got nothing instead"
    else:
      var holder = &atom
      var isCall = false

      if *firstTok:
        var postfixTokens = @[&firstTok]
        while not parser.tokenizer.eof:
          let savedTok = parser.tokenizer
          let next = parser.tokenizer.nextExceptWhitespace()
          if !next:
            break

          case (&next).kind
          of TokenKind.Dot, TokenKind.Identifier:
            postfixTokens &= &next
          of TokenKind.LParen:
            isCall = true
            if postfixTokens.len > 1:
              if (
                let callStmt = parser.parsePostfixCall(move(postfixTokens))
                *callStmt
              ):
                holder = &callStmt
            else:
              if (let callStmt = parser.parseFunctionCall((&firstTok).ident); *callStmt):
                holder = &callStmt
            break
          else:
            parser.tokenizer = savedTok
            break

        if not isCall and postfixTokens.len > 1:
          holder = postfixTokens
            .filterIt(it.kind == TokenKind.Identifier)
            .mapIt(it.ident)
            .createFieldAccess()
            .fieldHolder()

      expr = some Statement(
        kind: BinaryOp, binLeft: holder, binRight: holder, op: BinaryOperation.Equal
      )

  while not parser.tokenizer.eof:
    if (let tok = parser.tokenizer.nextExceptWhitespace(); *tok):
      let kind = (&tok).kind
      case kind
      of TokenKind.RParen:
        break
      of TokenKind.And:
        expr.applyThis:
          this.binLeft = binOp(this.op, this.binLeft, this.binRight)
          this.op = BinaryOperation.And
          if (
            let rhsExpr = parser.parseExprInParenWrap(TokenKind.And, compounding = true)
            *rhsExpr
          ):
            this.binRight = &rhsExpr
            break
          else:
            parser.error Other, &"expected right-hand-side expression after &&"
      else:
        parser.error Other, &"expected right parenthesis after expression, got {kind}"

  expr

proc parseForLoop(parser: Parser): Option[Statement] =
  template expectSemicolon(section: string) =
    let sectionEndingSemicolon = parser.tokenizer.nextExceptWhitespace()
    if !sectionEndingSemicolon:
      parser.error Other, "expected semicolon after " & section & ", got EOF."

    if (&sectionEndingSemicolon).kind != TokenKind.Semicolon:
      parser.error UnexpectedToken,
        "expected semicolon after " & section & ", got " &
          $(&sectionEndingSemicolon).kind

  let parenTok = parser.tokenizer.nextExceptWhitespace()
  if !parenTok:
    parser.error Other, "expected left facing parenthesis, got EOF instead."

  if (&parenTok).kind != TokenKind.LParen:
    parser.error UnexpectedToken,
      "expected left facing parenthesis, got " & $(&parenTok).kind

  let peekedNext = parser.tokenizer.peekExceptWhitespace()
  if !peekedNext:
    parser.error Other, "expected identifier or initializer statement, got EOF instead."

  if (&peekedNext).kind == TokenKind.Identifier:
    let
      storeIn = (&parser.tokenizer.nextExceptWhitespace()).ident
      ofToken = parser.tokenizer.nextExceptWhitespace()

    let iter = Statement(kind: ListIterator, iterStoresIn: some(storeIn))

    if !ofToken:
      parser.error Other, "expected `of` after identifier, got EOF instead."

    if (&ofToken).kind != TokenKind.Of:
      parser.error UnexpectedToken,
        "expected `of` after identifier, got " & $((&ofToken).kind)

    let peekedCollection = parser.tokenizer.peekExceptWhitespace()
    if !peekedCollection:
      parser.error Other, "expected array or identifier after `of`, got EOF instead."

    var sawRParen = false

    if (&peekedCollection).kind == TokenKind.Identifier:
      discard parser.tokenizer.nextExceptWhitespace()

      let collectionIdent = (&peekedCollection).ident
      var postfixTokens = newSeqOfCap[Token](1)
      postfixTokens &= &peekedCollection

      while not parser.tokenizer.eof:
        let succeedsCollection = parser.tokenizer.nextExceptWhitespace()

        if !succeedsCollection:
          parser.error Other,
            "expected left-facing parenthesis after identifier, got EOF instead."

        case (&succeedsCollection).kind
        of TokenKind.LParen:
          let call =
            if postfixTokens.len > 1:
              parser.parsePostfixCall(move(postfixTokens))
            else:
              parser.parseFunctionCall(collectionIdent)

          iter.iterList = &call
          break
        of TokenKind.RParen:
          let idents =
            postfixTokens.filterIt(it.kind == TokenKind.Identifier).mapIt(it.ident)
          if idents.len > 1:
            iter.iterList = fieldHolder(createFieldAccess(idents))
          else:
            iter.iterList = identHolder(collectionIdent)
          sawRParen = true
          break
        of TokenKind.Dot, TokenKind.Identifier:
          postfixTokens &= &succeedsCollection
        else:
          discard
    else:
      let atom = parser.parseAtom(&parser.tokenizer.nextExceptWhitespace())
      if *atom:
        iter.iterList = &atom

    if not sawRParen:
      let expectRParen = parser.tokenizer.nextExceptWhitespace()
      if !expectRParen or (&expectRParen).kind != TokenKind.RParen:
        parser.error Other, "Left-facing parenthesis must close collection iterator"

    iter.iterBody = Scope(stmts: parser.parseScope())

    return some(iter)
  else:
    var copiedTok = parser.tokenizer
    let initializer = parser.parseStatement()
    if !initializer:
      parser.tokenizer = ensureMove(copiedTok)

    expectSemicolon "initializer"

    copiedTok = parser.tokenizer
    let condition = parser.parseExpression()
    if !condition:
      parser.tokenizer = ensureMove(copiedTok)

    expectSemicolon "conditional"

    copiedTok = parser.tokenizer
    let incrementor = parser.parseStatement()
    if !incrementor:
      parser.tokenizer = ensureMove(copiedTok)

    let endingParen = parser.tokenizer.nextExceptWhitespace()
    if !endingParen:
      parser.error Other,
        "expected right facing parenthesis to close for-expression, got EOF."

    if (&endingParen).kind != TokenKind.RParen:
      parser.error UnexpectedToken,
        "expected right facing parenthesis to close for-expression, got " &
          $(&endingParen).kind

    let body = Scope(stmts: parser.parseScope())

    return some(forLoop(initializer, condition, incrementor, body))

proc parseTryClause(parser: Parser): Option[Statement] =
  var statement = Statement(kind: TryCatch)
  statement.tryStmtBody = Scope(stmts: parser.parseScope())
  statement.source = parser.lines[parser.tokenizer.location.line]

  var copied = parser.tokenizer

  if not copied.eof and
      (let tok = copied.nextExceptWhitespace(); *tok and (&tok).kind == TokenKind.Catch):
    parser.tokenizer = copied

    var copiedParen = parser.tokenizer
    if not copiedParen.eof and (
      let paren = copiedParen.nextExceptWhitespace()
      *paren and (&paren).kind == TokenKind.LParen
    ):
      parser.tokenizer = copiedParen
      let ident = parser.tokenizer.consumeIdentifier()
      statement.tryErrorCaptureIdent = some(ident.ident)

      if not parser.tokenizer.eof and
          (let endingParen = parser.tokenizer.nextExceptWhitespace(); *endingParen):
        if (&endingParen).kind != TokenKind.RParen:
          parser.error UnexpectedToken,
            "expected right parenthesis, got " & $((&endingParen).kind)
      else:
        parser.error Other, "expected right parenthesis after identifier, got EOF."

    statement.tryCatchBody = some(Scope(stmts: parser.parseScope()))

  some(ensureMove(statement))

proc parseCompoundAssignment(
    parser: Parser, target: string, compound: Token
): Option[Statement] =
  if parser.tokenizer.eof:
    parser.error Other,
      "expected equal-sign to start compound assignment, got EOF instead."

  let expEquals = parser.tokenizer.next()
  if expEquals.kind != TokenKind.EqualSign:
    parser.error Other,
      "expected equal-sign to start compound assignment, got " & $expEquals.kind &
        " instead."

  let copiedTok = parser.tokenizer
  let expr = parser.parseExpression()
  var atom: Option[Statement]
  var identifier: Option[string]

  if !expr:
    parser.tokenizer = copiedTok

    let next = &parser.tokenizer.nextExceptWhitespace()

    case next.kind
    of TokenKind.Identifier:
      var idents = @[next.ident]
      while not parser.tokenizer.eof:
        let saved = parser.tokenizer
        let peekTok = parser.tokenizer.nextExceptWhitespace()
        if *peekTok and (&peekTok).kind == TokenKind.Dot:
          let nextIdent = parser.tokenizer.nextExceptWhitespace()
          if *nextIdent and (&nextIdent).kind == TokenKind.Identifier:
            idents &= (&nextIdent).ident
          else:
            parser.error UnexpectedToken, "expected identifier after dot"
        else:
          parser.tokenizer = saved
          break
      identifier = some(idents.join("."))
    else:
      atom = parser.parseAtom(next)

  if *expr:
    parser.error Other, "Compound assignment with expressions is not supported yet"

  var binOp: BinaryOperation
  case compound.kind
  of TokenKind.Mul:
    binOp = BinaryOperation.Mult
  of TokenKind.Add:
    binOp = BinaryOperation.Add
  of TokenKind.Sub:
    binOp = BinaryOperation.Sub
  of TokenKind.Div:
    binOp = BinaryOperation.Div
  else:
    parser.error UnexpectedToken,
      "expected multiplication, addition, subtraction or division as compound, got " &
        $compound.kind & " instead"

  if *atom:
    var asgnExpr = compoundAssignment(binOp, target = target, compounder = &atom)
    asgnExpr.source = parser.lines[parser.tokenizer.location.line]

    return some(ensureMove(asgnExpr))
  elif *identifier:
    var asgnExpr = compoundAssignment(binOp, target = target, compounder = &identifier)
    asgnExpr.source = parser.lines[parser.tokenizer.location.line]

    return some(ensureMove(asgnExpr))
  else:
    parser.error Other,
      "expected expression, literal or identifier after compound assignment"

proc parseIndexes(parser: Parser, identifier: string): Option[Statement] =
  if parser.tokenizer.eof:
    parser.error Other, "expected identifier or numeric, got EOF."

  let indexKey = &parser.tokenizer.nextExceptWhitespace()

  if indexKey.kind notin {TokenKind.Identifier, TokenKind.Number}:
    parser.error UnexpectedToken,
      &"expected identifier or numeric, got {indexKey.kind} instead."

  if parser.tokenizer.eof:
    parser.error Other, "expected left-facing bracket, got EOF instead."

  if (
    let rbrack = parser.tokenizer.nextExceptWhitespace()
    !rbrack or (&rbrack).kind != TokenKind.RBracket
  ):
    parser.error UnexpectedToken, "expected left-facing bracket after indexing key"

  let access =
    case indexKey.kind
    of TokenKind.Identifier:
      arrayAccess(identifier, indexKey.ident)
    of TokenKind.Number:
      arrayAccess(identifier, &parser.parseAtom(indexKey))
    else:
      unreachable
      nil

  if parser.tokenizer.eof:
    return some(access)

  if (
    let expectingEquals = parser.tokenizer.nextExceptWhitespace()
    !expectingEquals or (&expectingEquals).kind == TokenKind.Equal
  ):
    return some(access)

  let source = &parser.tokenizer.nextExceptWhitespace()
  some(
    indexAssignment(
      source = (
        if (let atom = parser.parseAtom(source); *atom): &atom
        elif source.kind == TokenKind.Identifier: identHolder(source.ident)
        else: parser.error UnexpectedToken,
          &"expected identifier or value, got {source.kind} instead"
      ),
      dest = access,
    )
  )

proc parseStatement(parser: Parser): Option[Statement] =
  if parser.tokenizer.eof:
    return

  let tok = parser.tokenizer.nextExceptWhitespace()
  if !tok:
    return

  let token = &tok

  case token.kind
  of TokenKind.Let:
    if token.containsUnicodeEsc:
      parser.error Other, "keyword `let` cannot contain unicode escape(s)"

    return parser.parseDeclaration("let")
  of TokenKind.Const:
    if token.containsUnicodeEsc:
      parser.error Other, "keyword `const` cannot contain unicode escape(s)"

    return parser.parseDeclaration("const")
  of TokenKind.Var:
    if token.containsUnicodeEsc:
      parser.error Other, "keyword `var` cannot contain unicode escape(s)"

    return parser.parseDeclaration("var")
  of TokenKind.Function:
    if token.containsUnicodeEsc:
      parser.error Other, "keyword `function` cannot contain unicode escape(s)"

    let fnOpt = parser.parseFunction()

    if !fnOpt:
      parser.error Other, "unexpected end of input"

    var fn = &fnOpt

    var scope = parser.ast.scopes[parser.ast.currentScope]

    fn.prev = some(scope)
    scope.children &= Scope(fn)

    parser.ast.scopes[parser.ast.currentScope] = ensureMove(scope)
  of TokenKind.Identifier:
    var postfixTokens = @[token]

    while not parser.tokenizer.eof:
      let next = parser.tokenizer.nextExceptWhitespace()

      if !next:
        let targetIdent = postfixTokens
          .filterIt(it.kind == TokenKind.Identifier)
          .mapIt(it.ident)
          .join(".")
        return waste(targetIdent).some()

      let targetIdent = postfixTokens
        .filterIt(it.kind == TokenKind.Identifier)
        .mapIt(it.ident)
        .join(".")

      case (&next).kind
      of TokenKind.LParen:
        if postfixTokens.len > 1:
          return parser.parsePostfixCall(move(postfixTokens))
        else:
          return parser.parseFunctionCall(token.ident)
      of TokenKind.EqualSign:
        return parser.parseReassignment(targetIdent)
      of TokenKind.Increment:
        return some increment(targetIdent)
      of TokenKind.Decrement:
        return some decrement(targetIdent)
      of TokenKind.Mul, TokenKind.Add, TokenKind.Sub, TokenKind.Div:
        return parser.parseCompoundAssignment(targetIdent, &next)
      of TokenKind.LBracket:
        return parser.parseIndexes(targetIdent)
      of TokenKind.Dot, TokenKind.Identifier:
        postfixTokens &= &next
      else:
        parser.error UnexpectedToken,
          "expected left parenthesis, increment, decrement or equal sign, got " &
            $(&next).kind

    let targetIdent =
      postfixTokens.filterIt(it.kind == TokenKind.Identifier).mapIt(it.ident).join(".")
    return waste(targetIdent).some()
  of TokenKind.Return:
    if token.containsUnicodeEsc:
      parser.error Other, "keyword `return` cannot contain unicode escape(s)"

    let
      prevPos = parser.tokenizer.pos
      prevLoc = parser.tokenizer.location

    while not parser.tokenizer.eof():
      let next = parser.tokenizer.next()
      let copied = parser.tokenizer
      if (let expr = parser.parseExpression(); *expr):
        return some returnFunc(&expr)
      else:
        parser.tokenizer = copied

      case next.kind
      of TokenKind.Identifier:
        var idents = @[next.ident]
        while not parser.tokenizer.eof:
          let saved = parser.tokenizer
          let peekTok = parser.tokenizer.nextExceptWhitespace()
          if *peekTok and (&peekTok).kind == TokenKind.Dot:
            let nextIdent = parser.tokenizer.nextExceptWhitespace()
            if *nextIdent and (&nextIdent).kind == TokenKind.Identifier:
              idents &= (&nextIdent).ident
            else:
              parser.error UnexpectedToken, "expected identifier after dot"
          else:
            parser.tokenizer = saved
            break
        if idents.len > 1:
          return some returnFunc(fieldHolder(createFieldAccess(idents)))
        else:
          return some returnFunc(next.ident)
      of TokenKind.Number, TokenKind.String, TokenKind.True, TokenKind.False:
        return some returnFunc(&parser.parseAtom(next))
      of TokenKind.Whitespace:
        if next.whitespace.contains(strutils.Newlines):
          return some returnFunc()
      of TokenKind.Semicolon:
        break
      else:
        parser.error UnexpectedToken, "expected expression, got " & $next.kind

    parser.tokenizer.pos = prevPos
    parser.tokenizer.location = prevLoc
    return some returnFunc()
  of TokenKind.Throw:
    if token.containsUnicodeEsc:
      parser.error Other, "keyword `throw` cannot contain unicode escape(s)"

    return parser.parseThrow()
  of TokenKind.If:
    if token.containsUnicodeEsc:
      parser.error Other, "keyword `if` cannot contain unicode escape(s)"

    let expr = parser.parseExprInParenWrap(TokenKind.If)
    if !expr:
      return

    let body = parser.parseScope()
    var elseBody: seq[Statement]

    if not parser.tokenizer.eof and
        (let nextToken = parser.tokenizer.peekExceptWhitespace(); *nextToken):
      let next = &nextToken
      case next.kind
      of TokenKind.Else:
        discard parser.tokenizer.nextExceptWhitespace()
        elseBody = parser.parseScope()
      else:
        discard

    var lastScope = parser.ast.scopes[parser.ast.currentScope]
    var exprScope =
      Scope(stmts: parser.ast.scopes[parser.ast.currentScope + 1].stmts & body)
    var elseScope = Scope(stmts: elseBody)
    exprScope.prev = some(lastScope)
    elseScope.prev = some(lastScope)

    return some ifStmt(&expr, exprScope, elseScope)
  of TokenKind.While:
    if token.containsUnicodeEsc:
      parser.error Other, "keyword `while` cannot contain unicode escape(s)"

    let expr = parser.parseExprInParenWrap(TokenKind.While)
    if !expr:
      return

    let body = parser.parseScope()
    let lastScope = parser.ast.scopes[parser.ast.currentScope]
    var bodyScope =
      Scope(stmts: parser.ast.scopes[parser.ast.currentScope + 1].stmts & body)

    bodyScope.prev = some(lastScope)
    return some whileStmt(&expr, bodyScope)
  of TokenKind.New:
    if token.containsUnicodeEsc:
      parser.error Other, "keyword `new` cannot contain unicode escape(s)"

    let expr = parser.parseConstructor()
    if !expr:
      parser.error Other, "expected expression for `new`"

    return expr
  of TokenKind.Shebang:
    if parser.foundShebang:
      parser.error Other, "one file cannot have two shebangs"
    else:
      if parser.ast.scopes[parser.ast.currentScope].stmts.len > 0:
        parser.error Other, "shebang must be placed prior to other directives"

      if parser.precededByMultilineComment:
        parser.error Other, "shebang cannot be preceded by multiline comment"

      parser.foundShebang = true
  of TokenKind.Semicolon, TokenKind.Comma:
    discard
  of TokenKind.InvalidShebang:
    parser.error Other, "shebang cannot be preceded by whitespace"
  of TokenKind.Break:
    if token.containsUnicodeEsc:
      parser.error Other, "keyword `break` cannot contain unicode escape(s)."

    return some breakStmt()
  of TokenKind.String, TokenKind.Number, TokenKind.Null, TokenKind.LBracket,
      TokenKind.LCurly:
    let atom = parser.parseAtom(token)

    return atom
  of TokenKind.Comment:
    if token.multiline:
      parser.precededByMultilineComment = true

    if parser.opts.test262:
      try:
        {.cast(gcsafe).}:
          yaml.load(token.comment, parser.ast.test262)
      except CatchableError:
        discard
  of TokenKind.Typeof:
    let typeofCall = parser.parseTypeofCall()
    if !typeofCall:
      parser.error Other, "invalid usage of typeof"

    return some(call("BALI_TYPEOF".callFunction, &typeofCall, mangle = false))
  of TokenKind.For:
    return parser.parseForLoop()
  of TokenKind.Try:
    return parser.parseTryClause()
  of TokenKind.Increment:
    if parser.tokenizer.eof:
      parser.error Other, "expected expression after increment symbol, got EOF"

    let token = parser.tokenizer.nextExceptWhitespace()
    if !token:
      parser.error Other, "expected expression after increment symbol"

    let tok = &token
    if tok.kind != TokenKind.Identifier:
      parser.error UnexpectedToken, &"invalid increment operand '{tok.kind}'"

    var idents = @[tok.ident]
    while not parser.tokenizer.eof:
      let saved = parser.tokenizer
      let peekTok = parser.tokenizer.nextExceptWhitespace()
      if *peekTok and (&peekTok).kind == TokenKind.Dot:
        let nextIdent = parser.tokenizer.nextExceptWhitespace()
        if *nextIdent and (&nextIdent).kind == TokenKind.Identifier:
          idents &= (&nextIdent).ident
        else:
          parser.error UnexpectedToken, "expected identifier after dot"
      else:
        parser.tokenizer = saved
        break

    return some(preIncrement(idents.join(".")))
  else:
    parser.error UnexpectedToken, $token.kind

proc parse*(parser: Parser): AST {.inline.} =
  parser.ast = newAST()
  parser.lines = parser.tokenizer.source.split('\n').mapIt(it.strip(trailing = false))

  while not parser.tokenizer.eof():
    let stmt = parser.parseStatement()

    if *stmt:
      var statement = &stmt
      statement.line = parser.tokenizer.location.line
      statement.col = parser.tokenizer.location.col

      if parser.lines.len.uint > statement.line:
        statement.source = parser.lines[statement.line]

      case statement.kind
      of WhileStmt, IfStmt, ForLoop:
        parser.ast.scopes.delete(parser.ast.currentScope + 1)
      else:
        discard

      parser.ast.appendToCurrentScope(statement)

  parser.ast.errors = parser.errors
  parser.ast

{.pop.}

func newParser*(
    input: string, opts: ParserOpts = default(ParserOpts)
): Parser {.inline.} =
  ## This routine creates a new `Parser` object and returns it based
  ## off of the `input` string buffer, and optionally the `opts` struct
  ## that can be used to guide the parser in certain ways.
  Parser(tokenizer: newTokenizer(input), opts: opts)

{.pop.}
