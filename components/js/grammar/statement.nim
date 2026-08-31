import std/[hashes, options, tables]
import components/js/runtime/vm/atom
import components/js/runtime/normalize
import pkg/shakar

type
  StatementKind* = enum
    CreateImmutVal
    CreateMutVal
    NewFunction
    Call
    ReturnFn
    CallAndStoreResult
    ConstructObject
    ReassignVal
    ThrowError
    BinaryOp
    IdentHolder
    AtomHolder
    AccessField
    IfStmt
    CopyValMut
    CopyValImmut
    WhileStmt
    Increment
    Decrement
    Break
    Waste
    AccessArrayIndex
    TernaryOp
    ForLoop
    TryCatch
    CompoundAssignment
    DefineFunction
    CreateArrayLiteral
    FieldAccessHolder
    ListIterator
    CopyFieldToVar
    ConstructObjectShorthand
    PreIncrement
    IndexAssignment
    FunctionHolder

  FieldAccess* = ref object
    prev*, next*: FieldAccess
    identifier*: string

  CallArgKind* = enum
    cakIdent
    cakFieldAccess
    cakImmediateExpr
    cakAtom

  CallArg* = object
    case kind*: CallArgKind
    of cakIdent:
      ident*: string
    of cakAtom:
      atom*: MAtom
    of cakFieldAccess:
      access*: FieldAccess
    of cakImmediateExpr:
      expr*: Statement

  PositionedArguments* = seq[CallArg]

  Scope* = ref object of RootObj
    prev*: Option[Scope]
    children*: seq[Scope]
    stmts*: seq[Statement]

  Function* = ref object of Scope
    name*: string
    unmangled*: bool
    arguments*: seq[string] = @[] ## expected arguments!

  BinaryOperation* {.pure.} = enum
    Add
    Sub
    Mult
    Div
    Pow
    Invalid
    Equal
    TrueEqual
    GreaterThan
    GreaterOrEqual
    LesserThan
    LesserOrEqual
    NotEqual
    NotTrueEqual
    And
    Or

  FunctionCall* = object
    field*: Option[FieldAccess]
    ident*: Option[string]
    function*: string

  MixedLiteralChildren* = seq[Statement]
  KeyValuePairs* = Table[Statement, Statement]

  Statement* = ref object
    line*, col*: uint = 1
    source*: string
    storeIn*: Option[string]

    case kind*: StatementKind
    of CreateMutVal:
      mutIdentifier*: string
      mutAtom*: Statement
    of CreateImmutVal:
      imIdentifier*: string
      imAtom*: Statement
      imField*: FieldAccess
    of Call:
      fn*: FunctionCall
      arguments*: PositionedArguments
      mangle*: bool
      expectsReturnVal*: bool = false
    of NewFunction:
      fnName*: string
      body*: Scope
    of ReturnFn:
      retVal*: Option[MAtom]
      retIdent*: Option[string]
      retExpr*: Option[Statement]
    of CallAndStoreResult:
      mutable*: bool
      storeIdent*: string
      storeFn*: Statement
    of ConstructObject:
      objName*: string
      args*: PositionedArguments
    of ReassignVal:
      reIdentifier*: string
      reAtom*: MAtom
      reExpr*: Statement
    of ThrowError:
      error*: tuple[str: Option[string], exc: Option[void], ident: Option[string]]
    of BinaryOp:
      binLeft*, binRight*: Statement
      op*: BinaryOperation = BinaryOperation.Invalid
      binStoreIn*: Option[string]
    of IdentHolder:
      ident*: string
    of AtomHolder:
      atom*: MAtom
    of AccessField:
      identifier*: string
      field*: string
    of IfStmt:
      conditionExpr*: Statement
      branchTrue*: Scope
      branchFalse*: Scope
    of CopyValMut:
      cpMutSourceIdent*: string
      cpMutDestIdent*: string
    of CopyValImmut:
      cpImmutSourceIdent*: string
      cpImmutDestIdent*: string
    of WhileStmt:
      whConditionExpr*: Statement
      whBranch*: Scope
    of Increment, PreIncrement:
      incIdent*: string
    of Decrement:
      decIdent*: string
    of Waste:
      wstAtom*: Option[MAtom]
      wstIdent*: Option[string]
    of Break: discard
    of AccessArrayIndex:
      arrAccIdent*: string
      arrAccIndex*: Option[Statement]
      arrAccIdentIndex*: Option[string]
    of TernaryOp:
      ternaryCond*: Statement
      trueTernary*, falseTernary*: Statement
      ternaryStoreIn*: Option[string]
    of ForLoop:
      forLoopInitializer*: Option[Statement]
      forLoopCond*: Option[Statement]
      forLoopIter*: Option[Statement]
      forLoopBody*: Scope
    of TryCatch:
      tryStmtBody*: Scope
      tryCatchBody*: Option[Scope]
      tryErrorCaptureIdent*: Option[string]
    of CompoundAssignment:
      compAsgnOp*: BinaryOperation
      compAsgnTarget*: string
      compAsgnCompounder*: Option[Statement]
      compAsgnCompounderIdent*: Option[string]
    of DefineFunction:
      defunFn*: Function
      limitedTo*: Option[Scope]
    of CreateArrayLiteral:
      calChildren*: MixedLiteralChildren
    of FieldAccessHolder:
      fieldAccessList*: FieldAccess
    of ListIterator:
      iterStoresIn*: Option[string]
      iterList*: Statement
      iterBody*: Scope
    of CopyFieldToVar:
      cfvarField*: FieldAccess
      cfvarIdentDest*: Option[string]
      cfvarFieldDest*: Option[FieldAccess]
    of ConstructObjectShorthand:
      cosStoreIdent*: Option[string]
      cosKVPairs*: KeyValuePairs
    of IndexAssignment:
      indexAsgnSource*: Statement
      indexAsgnDest*: Statement
    of FunctionHolder:
      function*: Function

func hash*(access: FieldAccess): Hash {.inline.} =
  hash((access.identifier))

proc hash*(scope: Scope): Hash {.inline.}

proc hash*(call: FunctionCall): Hash {.inline.} =
  var hash = Hash(0)
  if *call.field:
    hash = hash !& hash(&call.field)

  if *call.ident:
    hash = hash !& hash(&call.ident)

  hash

proc hash*(stmt: Statement): Hash {.inline.} =
  var hash: Hash

  hash = hash !& stmt.kind.int

  {.cast(gcsafe).}:
    case stmt.kind
    of CreateMutVal:
      hash = hash !& hash((stmt.mutIdentifier, stmt.mutAtom))
    of CreateImmutVal:
      hash =
        hash !&
        hash((stmt.imIdentifier, cast[int64](stmt.imAtom), cast[int64](stmt.imField)))
    of Call:
      hash = hash !& hash((stmt.fn, stmt.arguments))
    of NewFunction:
      hash = hash !& hash((stmt.fnName))
    of BinaryOp:
      hash = hash !& hash((stmt.op))

      if stmt.binLeft != nil:
        hash = hash !& hash(stmt.binLeft)

      if stmt.binRight != nil:
        hash = hash !& hash(stmt.binRight)
    of IfStmt:
      hash = hash !& hash((stmt.conditionExpr))
    of AccessField:
      hash = hash !& hash((stmt.identifier, stmt.field))
    of AtomHolder:
      hash = hash !& hash(stmt.atom)
    of IdentHolder:
      hash = hash !& hash(stmt.ident)
    of WhileStmt:
      hash = hash !& hash((stmt.whConditionExpr, stmt.whBranch))
    else:
      discard

  hash

proc `$`*(stmt: Statement): string =
  case stmt.kind
  of AtomHolder:
    $stmt.atom
  else:
    $stmt.kind

proc hash*(fn: Function): Hash {.inline.} =
  when fn is Scope: # FIXME: really dumb fix to prevent a segfault
    hash(0)
  else:
    hash((fn.name, fn.arguments))

proc hash*(scope: Scope): Hash {.inline.} =
  var hash = Hash(0)

  if *scope.prev:
    hash = hash(&scope.prev)

  hash

func pushIdent*(args: var PositionedArguments, ident: string) {.inline.} =
  args &= CallArg(kind: cakIdent, ident: ident)

func createFieldAccess*(splitted: seq[string]): FieldAccess =
  ## From a sequence of identifiers (assuming they are in sorted order of accesses),
  ## create a `FieldAccess`, which has a "view" of the top of the field access chain.
  var
    top = FieldAccess(identifier: splitted[0])
    curr = top

  for ident in splitted[1 ..< splitted.len]:
    var acc = FieldAccess(identifier: ident)
    curr.next = acc
    acc.prev = curr

    curr = acc

  top

func pushFieldAccess*(args: var PositionedArguments, access: FieldAccess) {.inline.} =
  args &= CallArg(kind: cakFieldAccess, access: access)

func pushAtom*(args: var PositionedArguments, atom: MAtom) {.inline.} =
  args &= CallArg(kind: cakAtom, atom: atom)

func pushImmExpr*(args: var PositionedArguments, expr: Statement) {.inline.} =
  assert expr.kind in
    {BinaryOp, AccessArrayIndex, AtomHolder, DefineFunction, CreateArrayLiteral},
    "Attempt to push invalid expression to arguments: " & $expr.kind
  args &= CallArg(kind: cakImmediateExpr, expr: expr)

{.push checks: off, inline.}
func atomHolder*(atom: MAtom): Statement =
  Statement(kind: AtomHolder, atom: atom)

func identHolder*(ident: string): Statement =
  Statement(kind: IdentHolder, ident: ident)

func listIterator*(storesIn: string, iterList: Statement): Statement =
  Statement(kind: ListIterator, iterStoresIn: some(storesIn), iterList: iterList)

func fieldHolder*(access: FieldAccess): Statement =
  Statement(kind: FieldAccessHolder, fieldAccessList: access)

func constructObjectShort*(storeIdent: string, pairs: KeyValuePairs): Statement =
  Statement(
    kind: ConstructObjectShorthand, cosStoreIdent: some(storeIdent), cosKVPairs: pairs
  )

func defineFunction*(fn: Function, limitedTo: Option[Scope] = none(Scope)): Statement =
  Statement(kind: DefineFunction, defunFn: fn, limitedTo: limitedTo)

func copyFieldToVar*(dest: string, source: FieldAccess): Statement =
  Statement(kind: CopyFieldToVar, cfvarField: source, cfvarIdentDest: some(dest))

func copyFieldToVar*(dest: FieldAccess, source: FieldAccess): Statement =
  Statement(kind: CopyFieldToVar, cfvarField: source, cfvarFieldDest: some(dest))

func throwError*(
    errorStr: Option[string], errorExc: Option[void], errorIdent: Option[string]
): Statement =
  if *errorStr and *errorExc and *errorIdent:
    raise newException(
      ValueError,
      "Both `errorStr` and `errorExc` are full containers - something has went horribly wrong.",
    )

  Statement(kind: ThrowError, error: (str: errorStr, exc: errorExc, ident: errorIdent))

func createImmutVal*(name: string, atom: MAtom): Statement =
  Statement(kind: CreateImmutVal, imIdentifier: name, imAtom: atomHolder atom)

func createImmutVal*(name: string, field: FieldAccess): Statement =
  Statement(kind: CreateImmutVal, imIdentifier: name, imField: field)

func breakStmt*(): Statement =
  Statement(kind: Break)

func returnFunc*(): Statement =
  Statement(kind: ReturnFn)

func returnFunc*(expr: Statement): Statement =
  Statement(kind: ReturnFn, retExpr: some(expr))

func waste*(atom: MAtom): Statement =
  Statement(kind: Waste, wstAtom: atom.some())

func waste*(ident: string): Statement =
  Statement(kind: Waste, wstIdent: ident.some())

func forLoop*(
    initializer, condition, incrementor: Option[Statement], body: Scope
): Statement =
  Statement(
    kind: ForLoop,
    forLoopInitializer: initializer,
    forLoopCond: condition,
    forLoopIter: incrementor,
    forLoopBody: body,
  )

func increment*(ident: string): Statement =
  Statement(kind: Increment, incIdent: ident)

func arrayAccess*(ident: string, index: Statement): Statement =
  Statement(kind: AccessArrayIndex, arrAccIdent: ident, arrAccIndex: some(index))

func arrayAccess*(ident: string, index: string): Statement =
  Statement(kind: AccessArrayIndex, arrAccIdent: ident, arrAccIdentIndex: some(index))

func decrement*(ident: string): Statement =
  Statement(kind: Decrement, decIdent: ident)

func whileStmt*(condition: Statement, body: Scope): Statement =
  Statement(kind: WhileStmt, whConditionExpr: condition, whBranch: body)

func ifStmt*(condition: Statement, body, elseScope: Scope): Statement =
  Statement(
    kind: IfStmt, conditionExpr: condition, branchTrue: body, branchFalse: elseScope
  )

func copyValMut*(dest, source: string): Statement =
  Statement(kind: CopyValMut, cpMutSourceIdent: source, cpMutDestIdent: dest)

func copyValImmut*(dest, source: string): Statement =
  Statement(kind: CopyValImmut, cpImmutSourceIdent: source, cpImmutDestIdent: dest)

func binOp*(
    op: BinaryOperation,
    left, right: Statement,
    storeIdent: Option[string] = none(string),
): Statement =
  Statement(
    kind: BinaryOp, binLeft: left, binRight: right, op: op, binStoreIn: storeIdent
  )

func reassignVal*(identifier: string, atom: MAtom): Statement =
  Statement(kind: ReassignVal, reIdentifier: identifier, reAtom: atom)

func reassignVal*(identifier: string, expr: Statement): Statement =
  Statement(kind: ReassignVal, reIdentifier: identifier, reExpr: expr)

func returnFunc*(retVal: MAtom): Statement =
  Statement(kind: ReturnFn, retVal: some(retVal))

func returnFunc*(ident: string): Statement =
  Statement(kind: ReturnFn, retIdent: some(ident))

func callAndStoreImmut*(ident: string, fn: Statement): Statement =
  var fn = fn
  fn.expectsReturnVal = true
  Statement(kind: CallAndStoreResult, mutable: false, storeIdent: ident, storeFn: fn)

func callAndStoreMut*(ident: string, fn: Statement): Statement =
  var fn = fn
  fn.expectsReturnVal = true
  Statement(kind: CallAndStoreResult, mutable: true, storeIdent: ident, storeFn: fn)

func createMutVal*(name: string, atom: MAtom): Statement =
  Statement(kind: CreateMutVal, mutIdentifier: name, mutAtom: atomHolder atom)

func identArg*(ident: string): CallArg =
  CallArg(kind: cakIdent, ident: ident)

func atomArg*(atom: MAtom): CallArg =
  CallArg(kind: cakAtom, atom: atom)

func constructObject*(name: string, args: PositionedArguments): Statement =
  Statement(kind: ConstructObject, objName: name, args: args)

func call*(
    fn: FunctionCall,
    arguments: PositionedArguments,
    mangle: bool = true,
    expectsReturnVal: bool = false,
): Statement =
  Statement(
    kind: Call,
    fn: fn,
    arguments: arguments,
    mangle: mangle,
    expectsReturnVal: expectsReturnVal,
  )

func callFunction*(name: string): FunctionCall =
  FunctionCall(function: name)

func callFunction*(name: string, ident: string): FunctionCall =
  FunctionCall(function: name, ident: some(ident))

func callFunction*(name: string, field: FieldAccess): FunctionCall =
  FunctionCall(function: name, field: some field)

func compoundAssignment*(
    op: BinaryOperation, target: string, compounder: MAtom | Statement
): Statement =
  Statement(
    kind: CompoundAssignment,
    compAsgnTarget: target,
    compAsgnCompounder:
      when compounder is MAtom:
        some(atomHolder compounder)
      else:
        some(compounder),
    compAsgnOp: op,
  )

func compoundAssignment*(
    op: BinaryOperation, target: string, compounder: string
): Statement =
  Statement(
    kind: CompoundAssignment,
    compAsgnTarget: target,
    compAsgnCompounderIdent: some(compounder),
    compAsgnOp: op,
  )

func createArrayLiteral*(children: MixedLiteralChildren): Statement =
  Statement(kind: CreateArrayLiteral, calChildren: children)

func preIncrement*(ident: string): Statement =
  Statement(kind: PreIncrement, incIdent: ident)

func indexAssignment*(source, dest: Statement): Statement =
  Statement(kind: IndexAssignment, indexAsgnDest: dest, indexAsgnSource: source)

func functionHolder*(fn: Function): Statement =
  Statement(kind: FunctionHolder, function: fn)

{.pop.}

func normalizeIRName*(call: FunctionCall): string =
  return normalizeIRName(call.function)

func unwrap*(stmt: Statement): MAtom =
  if stmt.kind == AtomHolder:
    return stmt.atom

  raise newException(ValueError, "Cannot unwrap " & $stmt.kind)
