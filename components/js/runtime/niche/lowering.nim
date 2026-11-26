## This file contains all the routines that lower AST nodes to bytecode for the VM.
## 
## Copyright (C) 2024-2026 Trayambak Rai (xtrayambak@disroot.org)

import std/[options, hashes, strutils, tables, importutils]
import components/js/runtime/vm/ir/generator
import components/js/runtime/vm/prelude
import components/js/grammar/prelude
import pkg/shakar
import
  components/js/runtime/
    [normalize, types, atom_helpers, arguments, bridge, describe, construction]
import components/js/runtime/abstract/[to_string, equating]
import components/js/stdlib/prelude

privateAccess(Interpreter)
privateAccess(Runtime)
privateAccess(AllocStats)

const
  EntryPointName* = "@start"
  ThisIdent = "this"

proc generateBytecode(
  runtime: Runtime,
  fn: Function,
  stmt: Statement,
  internal: bool = false,
  ownerStmt: Option[Statement] = none(Statement),
  exprStoreIn: Option[string] = none(string),
  parentStmt: Option[Statement] = none(Statement),
  index: Option[uint] = none(uint),
) {.gcsafe.}

proc evalExpr(runtime: Runtime, fn: Function, expr: Statement): uint {.gcsafe.}

func allocTemp(runtime: Runtime): uint {.inline.} =
  result = runtime.realm.addrIdx
  inc runtime.realm.addrIdx

func generateLambdaName(runtime: Runtime): string {.inline.} =
  "@anon" & $runtime.realm.addrIdx

proc expand*(
    runtime: Runtime, fn: Function, stmt: Statement, internal: bool = false
) {.gcsafe.} =
  {.cast(gcsafe).}:
    case stmt.kind
    of Call:
      for i, arg in stmt.arguments:
        if arg.kind == cakAtom:
          discard runtime.loadIRAtom(arg.atom)
          runtime.markInternal(stmt, $i)
        elif arg.kind == cakImmediateExpr:
          let idx = runtime.evalExpr(fn, arg.expr)
          runtime.markInternal(stmt, $i, index = some(idx))
    of ConstructObject:
      for i, arg in stmt.args:
        if arg.kind == cakAtom:
          discard runtime.loadIRAtom(arg.atom)
          let name = $hash(stmt) & '_' & $i
          runtime.markInternal(stmt, name)
        elif arg.kind == cakImmediateExpr:
          let idx = runtime.evalExpr(fn, arg.expr)
          runtime.markInternal(stmt, $i, index = some(idx))
    of CallAndStoreResult:
      runtime.expand(fn, stmt.storeFn, internal)
    of ThrowError:
      if *stmt.error.str:
        runtime.generateBytecode(
          fn,
          decl("error_msg", atomHolder(stackStr(&stmt.error.str))),
          ownerStmt = some(stmt),
          internal = true,
        )
    of BinaryOp:
      if *stmt.storeIn:
        runtime.ir.loadInt(runtime.realm.addrIdx, 0)

        if not internal:
          runtime.markLocal(fn, &stmt.storeIn)
        else:
          runtime.markInternal(stmt, &stmt.storeIn)

      if stmt.binLeft.kind != StatementKind.IdentHolder:
        let idx = runtime.evalExpr(fn, stmt.binLeft)
        runtime.markInternal(stmt, "left_term", index = some(idx))

      if stmt.binRight.kind != StatementKind.IdentHolder:
        let idx = runtime.evalExpr(fn, stmt.binRight)
        runtime.markInternal(stmt, "right_term", index = some(idx))
    of IfStmt:
      let x = hash stmt

      var leftIdx = none(uint)
      if stmt.conditionExpr.binLeft.kind != IdentHolder:
        let idx = runtime.evalExpr(fn, stmt.conditionExpr.binLeft)
        runtime.markInternal(stmt, "left_term", index = some(idx))
        leftIdx = some(idx)

      let y = hash stmt
      assert x == y

      if stmt.conditionExpr.binRight.kind != IdentHolder:
        let idx =
          if stmt.conditionExpr.binRight == stmt.conditionExpr.binLeft and *leftIdx:
            &leftIdx
          else:
            runtime.evalExpr(fn, stmt.conditionExpr.binRight)
        runtime.markInternal(stmt, "right_term", index = some(idx))
    of WhileStmt:
      if stmt.whConditionExpr.binLeft.kind == AtomHolder:
        runtime.generateBytecode(
          fn,
          decl("left_term", atomHolder(stmt.whConditionExpr.binLeft.atom)),
          ownerStmt = some(stmt),
          internal = true,
        )

      if stmt.whConditionExpr.binRight.kind == AtomHolder:
        runtime.generateBytecode(
          fn,
          decl("right_term", atomHolder(stmt.whConditionExpr.binRight.atom)),
          ownerStmt = some(stmt),
          internal = true,
        )
    of ReturnFn:
      if *stmt.retVal:
        runtime.generateBytecode(
          fn,
          decl("retval", atomHolder(&stmt.retVal)),
          internal = true,
          ownerStmt = some(stmt),
        )
      elif *stmt.retExpr:
        let idx = runtime.evalExpr(fn, &stmt.retExpr)
        runtime.markInternal(stmt, "retval", index = some(idx))
      else:
        runtime.generateBytecode(
          fn,
          decl("retval", atomHolder(stackUndefined())),
          internal = true,
          ownerStmt = some(stmt),
        )
    of TernaryOp:
      if stmt.ternaryCond.kind != IdentHolder:
        let idx = runtime.evalExpr(fn, stmt.ternaryCond)
        runtime.markInternal(stmt, "cond_term", index = some(idx))
    else:
      discard

proc loadFieldAccessStrings*(runtime: Runtime, access: FieldAccess) =
  var curr = access.next
  assert(
    curr != nil,
    "Field access on single ident (or top of access chain was not provided)",
  )

  while curr != nil:
    runtime.ir.loadStr(runtime.realm.addrIdx, curr.identifier)
    runtime.ir.passArgument(runtime.realm.addrIdx)
    inc runtime.realm.addrIdx

    curr = curr.next

proc resolveFieldAccess*(
    runtime: Runtime, fn: Function, stmt: Statement, address: uint, access: FieldAccess
): uint =
  {.cast(gcsafe).}:
    let internalName = $(hash(stmt) !& hash(access.identifier))
  runtime.generateBytecode(
    fn,
    decl(internalName, atomHolder(stackNull())),
    internal = true,
    ownerStmt = some(stmt),
  )
  let accessResult = runtime.realm.addrIdx - 1

  var
    access = access.next
    accessSeq: seq[string]
  while access != nil:
    accessSeq &= access.identifier
    access = access.next

  runtime.ir.resolveField(address, accessResult, ensureMove(accessSeq))

  accessResult

proc generateBytecodeForScope*(
  runtime: Runtime, scope: Scope, allocateConstants: bool = true
) {.gcsafe.}

func willIRGenerateClause*(runtime: Runtime, clause: string): bool {.inline.} =
  for cls in runtime.ir.modules:
    if cls.name == clause:
      return true

  false

{.push gcsafe.}

proc resolveFieldOwner(
    runtime: Runtime, fn: Function, stmt: Statement, access: FieldAccess
): tuple[owner: uint, field: string] =
  let
    lastNode = tail(access)
    secondLastNode = back(lastNode)
    startObj = runtime.index(access.identifier, defaultParams(fn))
    owner =
      if !secondLastNode or &secondLastNode == access:
        startObj
      else:
        (&secondLastNode).next = nil
        let res = runtime.resolveFieldAccess(fn, stmt, startObj, access)
        (&secondLastNode).next = lastNode
        res

  (owner, lastNode.identifier)

proc genCall(
    runtime: Runtime,
    fn: Function,
    stmt: Statement,
    internal: bool,
    ownerStmt: Option[Statement],
) =
  var
    calleeAddr = none(uint)
    calleeThisBinding = none(uint)

  if *stmt.fn.callee:
    let callee = &stmt.fn.callee
    if callee.kind == AccessField:
      let
        thisBinding =
          if *callee.accessTarget:
            runtime.evalExpr(fn, &callee.accessTarget)
          else:
            runtime.index(callee.identifier, defaultParams(fn))
        fnAddr = runtime.allocTemp()
      runtime.ir.loadNull(fnAddr)
      runtime.ir.resolveField(thisBinding, fnAddr, @[callee.field])
      calleeThisBinding = some(thisBinding)
      calleeAddr = some(fnAddr)
    else:
      calleeAddr = some(runtime.evalExpr(fn, callee))

  runtime.expand(fn, stmt)
  runtime.ir.resetArgs()
  var nam =
    if stmt.mangle:
      stmt.fn.normalizeIRName()
    else:
      stmt.fn.function

  proc fillArguments() =
    var argumentRegs = newSeqUninit[uint](stmt.arguments.len)
    for i, arg in stmt.arguments:
      case arg.kind
      of cakIdent:
        argumentRegs[i] = runtime.index(arg.ident, defaultParams(fn))
      of cakAtom:
        let ident = $i
        argumentRegs[i] = runtime.index(ident, internalIndex(stmt))
      of cakFieldAccess:
        let index = runtime.resolveFieldAccess(
          fn, stmt, runtime.index(arg.access.identifier, defaultParams(fn)), arg.access
        )
        argumentRegs[i] = index
      of cakImmediateExpr:
        let index = runtime.index($i, internalIndex(stmt))
        argumentRegs[i] = index

    runtime.ir.passMultipleArguments(ensureMove(argumentRegs))

  if *calleeAddr:
    fillArguments()

    if *calleeThisBinding:
      runtime.ir.setThisBinding(&calleeThisBinding)

    runtime.ir.invoke(&calleeAddr)
  elif *stmt.fn.field:
    let
      topNode = &stmt.fn.field
      identName = topNode.identifier

      lastNode = tail(topNode)
      secondLastNode = back(lastNode)

      startObj = runtime.index(identName, defaultParams(fn))
      thisBinding =
        if &secondLastNode == topNode:
          startObj
        else:
          (&secondLastNode).next = nil
          let res = runtime.resolveFieldAccess(fn, stmt, startObj, topNode)
          (&secondLastNode).next = lastNode
          res
      callable = runtime.resolveFieldAccess(fn, stmt, thisBinding, &secondLastNode)

    fillArguments()
    runtime.ir.setThisBinding(thisBinding)
    runtime.ir.invoke(callable)
  else:
    fillArguments()

    let indexed = runtime.index(nam, defaultParams(fn), willHandleResolveFail = true)

    if indexed ==
        runtime.index("undefined", defaultParams(fn), willHandleResolveFail = true):
      runtime.ir.call(nam)
    else:
      runtime.ir.invoke(indexed)

  runtime.ir.resetArgs()

  if !ownerStmt:
    runtime.ir.zeroRetval()

proc genReturnFn(runtime: Runtime, fn: Function, stmt: Statement) =
  runtime.expand(fn, stmt)

  if *stmt.retVal or *stmt.retExpr:
    runtime.ir.returnFn(runtime.index("retval", internalIndex(stmt)).int)
  elif *stmt.retIdent:
    runtime.ir.returnFn(runtime.index(&stmt.retIdent, defaultParams(fn)).int)
  else:
    runtime.ir.returnFn(runtime.index("undefined", defaultParams(fn)).int)

proc genCallAndStoreResult(
    runtime: Runtime,
    fn: Function,
    stmt: Statement,
    ownerStmt: Option[Statement] = none(Statement),
) =
  runtime.generateBytecode(fn, stmt.storeFn, ownerStmt = some(stmt))
  var index =
    runtime.index(stmt.storeIdent, defaultParams(fn), willHandleResolveFail = true)

  if index == runtime.index("undefined", defaultParams(fn)):
    if *ownerStmt:
      runtime.markInternal(stmt, stmt.storeIdent)
      index = runtime.realm.addrIdx - 1
    else:
      runtime.markLocal(fn, stmt.storeIdent)
      index = runtime.realm.addrIdx - 1

  runtime.ir.loadUndefined(index)
  runtime.ir.readRegister(index, Register.ReturnValue)
  runtime.ir.zeroRetval()

proc genConstructObject(
    runtime: Runtime, fn: Function, stmt: Statement, internal: bool
) =
  runtime.expand(fn, stmt, internal)
  runtime.ir.resetArgs()

  var argumentRegs = newSeqUninit[uint](stmt.args.len + 1)
  argumentRegs[0] = runtime.index(stmt.objName, defaultParams(fn))
  for i, arg in stmt.args:
    case arg.kind
    of cakIdent:
      let ident = arg.ident
      argumentRegs[i + 1] = runtime.index(ident, defaultParams(fn))
    of cakAtom:
      {.cast(gcsafe).}:
        let ident = $hash(stmt) & '_' & $i
      argumentRegs[i + 1] = runtime.index(ident, internalIndex(stmt))
    of cakFieldAccess:
      argumentRegs[i + 1] = runtime.resolveFieldAccess(
        fn, stmt, runtime.index(arg.access.identifier, defaultParams(fn)), arg.access
      )
    of cakImmediateExpr:
      argumentRegs[i + 1] = runtime.index($i, internalIndex(stmt))

  runtime.ir.passMultipleArguments(ensureMove(argumentRegs))
  runtime.ir.call("BALI_ICTOR")
  runtime.ir.resetArgs()

proc genReassignVal(runtime: Runtime, fn: Function, stmt: Statement) =
  if stmt.reExpr != nil:
    let valIdx = runtime.evalExpr(fn, stmt.reExpr)
    if not stmt.reIdentifier.contains('.'):
      runtime.ir.copyAtom(valIdx, runtime.index(stmt.reIdentifier, defaultParams(fn)))
    else:
      let
        accesses = createFieldAccess(stmt.reIdentifier.split('.'))
        (owner, field) = runtime.resolveFieldOwner(fn, stmt, accesses)
      runtime.ir.writeField(owner, field, valIdx)
  elif not stmt.reIdentifier.contains('.'):
    let index = runtime.index(stmt.reIdentifier, defaultParams(fn))

    case stmt.reAtom.kind
    of Integer:
      runtime.ir.loadInt(index, stmt.reAtom)
    of String:
      runtime.ir.loadStr(index, stmt.reAtom)
    of Float:
      runtime.ir.loadFloat(index, stmt.reAtom)
    of Null:
      runtime.ir.loadNull(index)
    else:
      let atomIndex = runtime.loadIRAtom(stmt.reAtom)
      inc runtime.realm.addrIdx
      runtime.ir.copyAtom(atomIndex, index)
  else:
    let
      accesses = createFieldAccess(stmt.reIdentifier.split('.'))
      (owner, field) = runtime.resolveFieldOwner(fn, stmt, accesses)
      atomIndex = runtime.loadIRAtom(stmt.reAtom)

    inc runtime.realm.addrIdx
    runtime.ir.writeField(owner, field, atomIndex)

proc genThrowError(runtime: Runtime, fn: Function, stmt: Statement, internal: bool) =
  let errorTmp = runtime.allocTemp()

  runtime.ir.resetArgs()

  if *stmt.error.str:
    runtime.expand(fn, stmt, internal)

    runtime.ir.passArgument(runtime.index("Error", globalIndex()))
    runtime.ir.passArgument(runtime.index("error_msg", internalIndex(stmt)))

    runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
      (message: stmt.source, line: stmt.line)
  elif *stmt.error.ident:
    runtime.ir.passArgument(runtime.index("Error", globalIndex()))
    runtime.ir.passArgument(runtime.index(&stmt.error.ident, defaultParams(fn)))

    runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
      (message: stmt.source, line: stmt.line)
  else:
    unreachable

  runtime.ir.call(BuiltinInvokeCtor)
  runtime.ir.resetArgs()
  runtime.ir.readRegister(errorTmp, Register.ReturnValue)

  runtime.ir.passArgument(errorTmp)
  runtime.ir.call("BALI_THROWERROR")
  runtime.ir.resetArgs()

proc genBinaryOp(
    runtime: Runtime,
    fn: Function,
    stmt: Statement,
    internal: bool,
    parentStmt: Option[Statement] = none(Statement),
    exprStoreIn: Option[string] = none(string),
) =
  runtime.expand(fn, stmt, internal)

  let
    leftTerm = stmt.binLeft
    rightTerm = stmt.binRight

  var
    leftIdx =
      if leftTerm.kind == IdentHolder:
        runtime.index(leftTerm.ident, defaultParams(fn))
      else:
        runtime.index("left_term", internalIndex(stmt))

    rightIdx =
      if rightTerm.kind == IdentHolder:
        runtime.index(rightTerm.ident, defaultParams(fn))
      else:
        runtime.index("right_term", internalIndex(stmt))

  if leftTerm.kind == IdentHolder:
    if not internal and *stmt.binStoreIn and leftTerm.ident != &stmt.binStoreIn:
      runtime.markLocal(fn, &stmt.binStoreIn)
      runtime.ir.copyAtom(leftIdx, runtime.realm.addrIdx - 1)
      leftIdx = runtime.realm.addrIdx - 1
    elif internal or not (*stmt.binStoreIn):
      runtime.markInternal(stmt, "left_term")
      let tempLeftIdx = runtime.realm.addrIdx - 1
      runtime.ir.copyAtom(leftIdx, tempLeftIdx)
      leftIdx = tempLeftIdx

  let boolTargetIdx =
    if leftTerm.kind != IdentHolder:
      leftIdx
    elif *stmt.binStoreIn:
      if internal and *parentStmt:
        runtime.index(&stmt.binStoreIn, internalIndex(&parentStmt))
      else:
        runtime.index(&stmt.binStoreIn, defaultParams(fn))
    elif *exprStoreIn and *parentStmt:
      runtime.index(&exprStoreIn, internalIndex(&parentStmt))
    else:
      leftIdx

  case stmt.op
  of BinaryOperation.Add:
    runtime.ir.add(leftIdx, rightIdx)
  of BinaryOperation.Sub:
    runtime.ir.sub(leftIdx, rightIdx)
  of BinaryOperation.Mult:
    runtime.ir.mult(leftIdx, rightIdx)
  of BinaryOperation.Div:
    runtime.ir.divide(leftIdx, rightIdx)
  of BinaryOperation.Equal, BinaryOperation.TrueEqual:
    runtime.ir.passMultipleArguments(@[leftIdx, rightIdx])
    runtime.ir.call(
      if stmt.op == BinaryOperation.Equal:
        "BALI_EQUATE_ATOMS"
      else:
        "BALI_EQUATE_ATOMS_STRICT"
    )
    let
      equalJmp = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
      unequalJmp = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
      equalBranch = runtime.ir.loadBool(boolTargetIdx, true)
    runtime.ir.overrideArgs(equalJmp, @[stackInteger(equalBranch)])
    runtime.ir.jump(equalBranch + 3)

    let unequalBranch = runtime.ir.loadBool(boolTargetIdx, false)
    runtime.ir.overrideArgs(unequalJmp, @[stackInteger(unequalBranch)])
    leftIdx = boolTargetIdx
  of BinaryOperation.NotEqual:
    runtime.ir.passMultipleArguments(@[leftIdx, rightIdx])
    runtime.ir.call("BALI_EQUATE_ATOMS")
    let
      equalJmp = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
      unequalJmp = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
      unequalBranch = runtime.ir.loadBool(boolTargetIdx, true)
    runtime.ir.overrideArgs(unequalJmp, @[stackInteger(unequalBranch)])
    runtime.ir.jump(unequalBranch + 3)

    let equalBranch = runtime.ir.loadBool(boolTargetIdx, false)
    runtime.ir.overrideArgs(equalJmp, @[stackInteger(equalBranch)])
    leftIdx = boolTargetIdx
  of BinaryOperation.GreaterThan:
    runtime.ir.greaterThan(leftIdx, rightIdx)
  of BinaryOperation.GreaterOrEqual:
    runtime.ir.greaterThanEqual(leftIdx, rightIdx)
  of BinaryOperation.LesserThan:
    runtime.ir.lesserThan(leftIdx, rightIdx)
  of BinaryOperation.LesserOrEqual:
    runtime.ir.lesserThanEqual(leftIdx, rightIdx)
  else:
    discard

  if *stmt.binStoreIn:
    let address =
      if internal and *parentStmt:
        runtime.index(&stmt.binStoreIn, internalIndex(&parentStmt))
      else:
        runtime.index(&stmt.binStoreIn, defaultParams(fn))

    if leftIdx != address:
      runtime.ir.copyAtom(leftIdx, address)
  elif *exprStoreIn:
    assert *parentStmt
    let address = runtime.index(&exprStoreIn, internalIndex(&parentStmt))
    if leftIdx != address:
      runtime.ir.copyAtom(leftIdx, address)

  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genIfStmt(runtime: Runtime, fn: Function, stmt: Statement) =
  runtime.expand(fn, stmt)

  let
    lhsIdx =
      if stmt.conditionExpr.binLeft.kind == IdentHolder:
        runtime.index(stmt.conditionExpr.binLeft.ident, defaultParams(fn))
      else:
        runtime.index("left_term", internalIndex(stmt))

    rhsIdx =
      if stmt.conditionExpr.binRight.kind == IdentHolder:
        runtime.index(stmt.conditionExpr.binRight.ident, defaultParams(fn))
      else:
        runtime.index("right_term", internalIndex(stmt))

  case stmt.conditionExpr.op
  of BinaryOperation.Equal, BinaryOperation.NotEqual, BinaryOperation.TrueEqual:
    runtime.ir.passMultipleArguments(@[lhsIdx, rhsIdx])
    runtime.ir.call(
      if stmt.conditionExpr.op != BinaryOperation.TrueEqual:
        "BALI_EQUATE_ATOMS"
      else:
        "BALI_EQUATE_ATOMS_STRICT"
    )
  of BinaryOperation.GreaterThan:
    runtime.ir.greaterThan(lhsIdx, rhsIdx)
  of BinaryOperation.LesserThan:
    runtime.ir.lesserThan(lhsIdx, rhsIdx)
  of BinaryOperation.GreaterOrEqual:
    runtime.ir.greaterThanEqual(lhsIdx, rhsIdx)
  of BinaryOperation.LesserOrEqual:
    runtime.ir.lesserThanEqual(lhsIdx, rhsIdx)
  of BinaryOperation.And:
    discard
  else:
    unreachable

  let
    trueJump = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
    falseJump = runtime.ir.addOp(IROperation(opcode: Jump)) - 1

  proc getCurrOpNum(): int =
    for module in runtime.ir.modules:
      if module.name == runtime.ir.currModule:
        return module.operations.len + 1

    unreachable
    0

  runtime.generateBytecodeForScope(stmt.branchTrue, allocateConstants = false)
  let
    skipBranchTwoJmp = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
    endOfBranchOne = getCurrOpNum().uint

  runtime.generateBytecodeForScope(stmt.branchFalse, allocateConstants = false)
  let endOfBranchTwo = getCurrOpNum().uint
  runtime.ir.overrideArgs(skipBranchTwoJmp, @[stackInteger(endOfBranchTwo)])

  case stmt.conditionExpr.op
  of BinaryOperation.Equal, BinaryOperation.GreaterThan, BinaryOperation.TrueEqual,
      BinaryOperation.GreaterOrEqual, BinaryOperation.LesserThan,
      BinaryOperation.LesserOrEqual:
    runtime.ir.overrideArgs(falseJump, @[stackInteger(endOfBranchOne)])
    runtime.ir.overrideArgs(trueJump, @[stackInteger(falseJump + 2)])
  of BinaryOperation.NotEqual:
    runtime.ir.overrideArgs(trueJump, @[stackInteger(getCurrOpNum().uint)])
    runtime.ir.overrideArgs(falseJump, @[stackInteger(falseJump + 2)])
  of BinaryOperation.And:
    discard
  else:
    unreachable

  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genCopyValMut(runtime: Runtime, fn: Function, stmt: Statement) =
  let preExistingDestIndex =
    runtime.index(stmt.cpMutDestIdent, defaultParams(fn), willHandleResolveFail = true)

  if preExistingDestIndex == runtime.index("undefined", defaultParams(fn)):
    runtime.generateBytecode(
      fn, decl(stmt.cpMutDestIdent, atomHolder(stackNull())), internal = false
    )
    let dest = runtime.realm.addrIdx - 1

    if stmt.cpMutDestIdent.contains('.'):
      let
        fields = createFieldAccess(stmt.cpMutDestIdent.split('.'))
        (owner, field) = runtime.resolveFieldOwner(fn, stmt, fields)

      runtime.ir.writeField(
        owner, field, runtime.index(stmt.cpMutSourceIdent, defaultParams(fn))
      )
    else:
      runtime.ir.copyAtom(runtime.index(stmt.cpMutSourceIdent, defaultParams(fn)), dest)

    runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
      (message: stmt.source, line: stmt.line)
  else:
    runtime.ir.copyAtom(
      runtime.index(stmt.cpMutSourceIdent, defaultParams(fn)), preExistingDestIndex
    )

proc genCopyValImmut(runtime: Runtime, fn: Function, stmt: Statement) =
  runtime.generateBytecode(
    fn, decl(stmt.cpImmutDestIdent, atomHolder(stackNull())), internal = false
  )
  let dest = runtime.realm.addrIdx - 1

  runtime.ir.copyAtom(runtime.index(stmt.cpImmutSourceIdent, defaultParams(fn)), dest)

  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genWhileStmt(runtime: Runtime, fn: Function, stmt: Statement) =
  runtime.expand(fn, stmt)

  proc getCurrOpNum(): int =
    for module in runtime.ir.modules:
      if module.name == runtime.ir.currModule:
        return module.operations.len + 1

    unreachable
    0

  let
    jmpIntoComparison = getCurrOpNum()
    lhsIdx =
      case stmt.whConditionExpr.binLeft.kind
      of IdentHolder:
        runtime.index(stmt.whConditionExpr.binLeft.ident, defaultParams(fn))
      of AtomHolder:
        runtime.index("left_term", internalIndex(stmt))
      else:
        runtime.evalExpr(fn, stmt.whConditionExpr.binLeft)

    rhsIdx =
      if stmt.whConditionExpr.binRight == stmt.whConditionExpr.binLeft and
          stmt.whConditionExpr.binRight.kind notin {IdentHolder, AtomHolder}:
        lhsIdx
      else:
        case stmt.whConditionExpr.binRight.kind
        of IdentHolder:
          runtime.index(stmt.whConditionExpr.binRight.ident, defaultParams(fn))
        of AtomHolder:
          runtime.index("right_term", internalIndex(stmt))
        else:
          runtime.evalExpr(fn, stmt.whConditionExpr.binRight)

  case stmt.whConditionExpr.op
  of Equal, NotEqual, TrueEqual:
    runtime.ir.passArgument(lhsIdx)
    runtime.ir.passArgument(rhsIdx)
    runtime.ir.call(
      if stmt.whConditionExpr.op != BinaryOperation.TrueEqual:
        "BALI_EQUATE_ATOMS"
      else:
        "BALI_EQUATE_ATOMS_STRICT"
    )
  of GreaterThan:
    runtime.ir.greaterThan(lhsIdx, rhsIdx)
  of LesserThan:
    runtime.ir.lesserThan(lhsIdx, rhsIdx)
  of GreaterOrEqual:
    runtime.ir.greaterThanEqual(lhsIdx, rhsIdx)
  of LesserOrEqual:
    runtime.ir.lesserThanEqual(lhsIdx, rhsIdx)
  else:
    unreachable

  let
    trueJump = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
    escapeJump = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
    dummyJump = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
    jmpIntoBody = getCurrOpNum()

  runtime.generateBytecodeForScope(stmt.whBranch, allocateConstants = false)

  runtime.ir.jump(jmpIntoComparison.uint)

  let jmpPastBody = getCurrOpNum()

  if runtime.irHints.breaksGeneratedAt.len > 0:
    for brk in runtime.irHints.breaksGeneratedAt:
      runtime.ir.overrideArgs(brk, @[stackInteger(jmpPastBody.uint)])
  else:
    runtime.ir.overrideArgs(dummyJump, @[stackInteger(jmpPastBody.uint)])

  runtime.irHints.breaksGeneratedAt.reset()

  case stmt.whConditionExpr.op
  of BinaryOperation.Equal, BinaryOperation.TrueEqual, BinaryOperation.GreaterThan,
      BinaryOperation.LesserThan, BinaryOperation.GreaterOrEqual,
      BinaryOperation.LesserOrEqual:
    runtime.ir.overrideArgs(trueJump, @[stackInteger(jmpIntoBody.uint)])
    runtime.ir.overrideArgs(escapeJump, @[stackInteger(jmpPastBody.uint)])
  of BinaryOperation.NotEqual:
    runtime.ir.overrideArgs(trueJump, @[stackInteger(jmpPastBody.uint)])
    runtime.ir.overrideArgs(escapeJump, @[stackInteger(jmpIntoBody.uint)])
  else:
    unreachable

  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genIncrement(runtime: Runtime, fn: Function, stmt: Statement) {.inline.} =
  runtime.ir.incrementInt(runtime.index(stmt.incIdent, defaultParams(fn)))
  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genDecrement(runtime: Runtime, fn: Function, stmt: Statement) {.inline.} =
  runtime.ir.decrementInt(runtime.index(stmt.decIdent, defaultParams(fn)))
  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genBreak(runtime: Runtime, fn: Function, stmt: Statement) {.inline.} =
  runtime.irHints.breaksGeneratedAt &= runtime.ir.addOp(IROperation(opcode: Jump)) - 1
  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genWaste(runtime: Runtime, fn: Function, stmt: Statement) =
  assert(
    not (*stmt.wstAtom and *stmt.wstIdent), "Cannot waste atom and identifier at once!"
  )

  let idx =
    if *stmt.wstAtom:
      runtime.loadIRAtom(&stmt.wstAtom)
    elif *stmt.wstIdent:
      runtime.index(&stmt.wstIdent, defaultParams(fn))
    else:
      unreachable
      0'u

  if runtime.opts.repl:
    runtime.ir.passArgument(idx)
    var args: PositionedArguments

    if *stmt.wstAtom:
      args.pushAtom(&stmt.wstAtom)
    elif *stmt.wstIdent:
      args.pushIdent(&stmt.wstIdent)
    else:
      unreachable

    runtime.generateBytecode(
      fn,
      call(
        callFunction(
          FieldAccess(identifier: "console", next: FieldAccess(identifier: "log"))
        ),
        ensureMove(args),
        expectsReturnVal = false,
      ),
    )

  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genAccessField(
    runtime: Runtime,
    fn: Function,
    stmt: Statement,
    parentStmt: Option[Statement],
    storeIn: Option[string] = none(string),
) =
  let
    targetAddr =
      if *stmt.accessTarget:
        runtime.evalExpr(fn, &stmt.accessTarget)
      else:
        runtime.index(stmt.identifier, defaultParams(fn))
    dest =
      if *storeIn and *parentStmt:
        runtime.index(&storeIn, internalIndex(&parentStmt))
      else:
        runtime.allocTemp()

  runtime.ir.loadNull(dest)
  runtime.ir.resolveField(targetAddr, dest, @[stmt.field])
  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genAccessArrayIndex(
    runtime: Runtime,
    fn: Function,
    stmt: Statement,
    parentStmt: Option[Statement],
    storeIn: Option[string] = none(string),
) =
  let
    atomIdx =
      if *stmt.arrAccTarget:
        runtime.evalExpr(fn, &stmt.arrAccTarget)
      else:
        runtime.index(stmt.arrAccIdent, defaultParams(fn))
    fieldIndex =
      if *stmt.arrAccIndex:
        runtime.evalExpr(fn, &stmt.arrAccIndex)
      elif *stmt.arrAccIdentIndex:
        runtime.index(&stmt.arrAccIdentIndex, defaultParams(fn))
      else:
        unreachable
        0'u

  runtime.ir.resetArgs()
  runtime.ir.passArgument(atomIdx)
  runtime.ir.passArgument(fieldIndex)
  runtime.ir.call("BALI_INDEX")

  if *storeIn:
    assert(*parentStmt)
    runtime.ir.readRegister(
      runtime.index(&storeIn, internalIndex(&parentStmt)), Register.ReturnValue
    )

  runtime.ir.resetArgs()
  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genIndexAssignment(runtime: Runtime, fn: Function, stmt: Statement) =
  let dest = stmt.indexAsgnDest

  case dest.kind
  of AccessField:
    let
      targetAddr =
        if *dest.accessTarget:
          runtime.evalExpr(fn, &dest.accessTarget)
        else:
          runtime.index(dest.identifier, defaultParams(fn))
      valIdx = runtime.evalExpr(fn, stmt.indexAsgnSource)

    runtime.ir.writeField(targetAddr, dest.field, valIdx)
  of AccessArrayIndex:
    let
      targetAddr =
        if *dest.arrAccTarget:
          runtime.evalExpr(fn, &dest.arrAccTarget)
        else:
          runtime.index(dest.arrAccIdent, defaultParams(fn))
      valIdx = runtime.evalExpr(fn, stmt.indexAsgnSource)

    if *dest.arrAccIndex and (&dest.arrAccIndex).kind == AtomHolder:
      let
        atom = (&dest.arrAccIndex).atom
        key =
          case atom.kind
          of String:
            &atom.getStr()
          of Integer:
            $(&atom.getInt())
          of Float:
            $(int(&atom.getNumeric()))
          else:
            unreachable
            newString(0)

      runtime.ir.writeField(targetAddr, key, valIdx)
    else:
      unreachable
  else:
    unreachable

  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genTernaryOp(
    runtime: Runtime,
    fn: Function,
    stmt: Statement,
    internal: bool = false,
    parentStmt: Option[Statement] = none(Statement),
    exprStoreIn: Option[string] = none(string),
) =
  let targetStore = if *stmt.ternaryStoreIn: stmt.ternaryStoreIn else: stmt.storeIn

  if not (*targetStore or *exprStoreIn):
    return

  runtime.expand(fn, stmt, internal)

  let addrOfCond =
    if stmt.ternaryCond.kind == IdentHolder:
      runtime.index(stmt.ternaryCond.ident, defaultParams(fn))
    else:
      runtime.index("cond_term", internalIndex(stmt))

  proc getCurrOpNum(): uint =
    for module in runtime.ir.modules:
      if module.name == runtime.ir.currModule:
        return uint(module.operations.len + 1)

    unreachable
    0'u

  let finalAddr =
    if *targetStore:
      if internal and *parentStmt:
        runtime.index(&targetStore, internalIndex(&parentStmt))
      else:
        let existing =
          runtime.index(&targetStore, defaultParams(fn), willHandleResolveFail = true)
        if existing ==
            runtime.index("undefined", defaultParams(fn), willHandleResolveFail = true):
          runtime.ir.loadNull(runtime.realm.addrIdx)
          runtime.markLocal(fn, &targetStore)
          runtime.realm.addrIdx - 1
        else:
          existing
    else:
      assert *parentStmt
      runtime.index(&exprStoreIn, internalIndex(&parentStmt))

  proc emitBranch(branch: Statement) =
    let idx = runtime.evalExpr(fn, branch)
    if idx != finalAddr:
      runtime.ir.copyAtom(idx, finalAddr)

  runtime.ir.passMultipleArguments(
    @[addrOfCond, runtime.index("true", defaultParams(fn))]
  )
  runtime.ir.call("BALI_EQUATE_ATOMS")

  let
    trueJump = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
    falseJump = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
    trueBranchStart = getCurrOpNum()

  emitBranch(stmt.trueTernary)
  let
    skipFalseJump = runtime.ir.addOp(IROperation(opcode: Jump)) - 1
    falseBranchStart = getCurrOpNum()

  emitBranch(stmt.falseTernary)
  let endOfTernary = getCurrOpNum()

  runtime.ir.overrideArgs(trueJump, @[stackInteger(trueBranchStart)])
  runtime.ir.overrideArgs(falseJump, @[stackInteger(falseBranchStart)])
  runtime.ir.overrideArgs(skipFalseJump, @[stackInteger(endOfTernary)])

  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genForLoop(runtime: Runtime, fn: Function, stmt: Statement) =
  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

  if *stmt.forLoopInitializer:
    runtime.generateBytecode(fn, &stmt.forLoopInitializer)

  proc getCurrOpNum(): uint =
    for module in runtime.ir.modules:
      if module.name == runtime.ir.currModule:
        return uint(module.operations.len + 1)

    unreachable
    0'u

  let conditionalJump = getCurrOpNum()

  var inverted = false
  if *stmt.forLoopCond:
    let cond = &stmt.forLoopCond
    inverted = cond.op in {BinaryOperation.LesserThan}
    runtime.generateBytecode(fn, cond)
  else:
    unreachable

  let
    jmpIntoBody = stackInteger(getCurrOpNum() + 2'u)
    jump1 = runtime.ir.placeholder(Jump) - 1
    jump2 = runtime.ir.placeholder(Jump) - 1

  runtime.generateBytecodeForScope(stmt.forLoopBody, allocateConstants = false)

  if *stmt.forLoopIter:
    runtime.generateBytecode(fn, &stmt.forLoopIter)

  let jmpOutsideBody = stackInteger(getCurrOpNum() + 1'u)

  if not inverted:
    runtime.ir.overrideArgs(jump1, @[jmpIntoBody])
    runtime.ir.overrideArgs(jump2, @[jmpOutsideBody])
  else:
    runtime.ir.overrideArgs(jump1, @[jmpOutsideBody])
    runtime.ir.overrideArgs(jump2, @[jmpIntoBody])

  runtime.ir.jump(conditionalJump)

proc genTryClause(runtime: Runtime, fn: Function, stmt: Statement) =
  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

  let excHandler = runtime.ir.placeholder(JumpOnError) - 1

  runtime.generateBytecodeForScope(stmt.tryStmtBody, allocateConstants = false)

  proc getCurrOpNum(): int =
    for module in runtime.ir.modules:
      if module.name == runtime.ir.currModule:
        return module.operations.len + 1

    unreachable
    0

  runtime.ir.overrideArgs(excHandler, @[getCurrOpNum().stackInteger])
  if *stmt.tryCatchBody:
    if *stmt.tryErrorCaptureIdent:
      runtime.markLocal(fn = fn, ident = &stmt.tryErrorCaptureIdent)
      let errorCaptureIndex = runtime.realm.addrIdx - 1

      runtime.ir.readRegister(errorCaptureIndex, Register.Error)

    runtime.generateBytecodeForScope(&stmt.tryCatchBody, allocateConstants = false)

proc genCompoundAsgn(runtime: Runtime, fn: Function, stmt: Statement) =
  let
    target = runtime.index(stmt.compAsgnTarget, defaultParams(fn))
    compounder =
      if *stmt.compAsgnCompounder:
        runtime.loadIRAtom(unwrap &stmt.compAsgnCompounder)
      elif *stmt.compAsgnCompounderIdent:
        runtime.index(&stmt.compAsgnCompounderIdent, defaultParams(fn))
      else:
        unreachable
        0'u

  case stmt.compAsgnOp
  of BinaryOperation.Mult:
    runtime.ir.mult(target, compounder)
  of BinaryOperation.Div:
    runtime.ir.divide(target, compounder)
  of BinaryOperation.Add:
    runtime.ir.add(target, compounder)
  of BinaryOperation.Sub:
    runtime.ir.sub(target, compounder)
  else:
    unreachable

  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
    (message: stmt.source, line: stmt.line)

proc genDefineFunction(
    runtime: Runtime,
    fn: Function,
    stmt: Statement,
    parent: Option[Statement],
    storeIn: Option[string],
): uint =
  if runtime.ir.cachedIndex > 0:
    runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex - 1] =
      (message: stmt.source, line: stmt.line)

  let
    prevCachedIndex = runtime.ir.cachedIndex
    moduleName = runtime.ir.currModule
    defun = stmt.defunFn
    name =
      if defun.name.len < 1:
        generateLambdaName(runtime)
      else:
        defun.name

  defun.name = name
  if !defun.prev:
    defun.prev = some(Scope(fn))

  runtime.generateBytecodeForScope(Scope(defun), allocateConstants = false)

  runtime.ir.cachedIndex = prevCachedIndex
  runtime.ir.cachedModule = nil
  runtime.ir.currModule = moduleName

  let dest =
    if *storeIn and *parent:
      runtime.index(&storeIn, internalIndex(&parent))
    else:
      let idx = runtime.realm.addrIdx
      runtime.markLocal(fn, name)
      idx

  runtime.ir.loadBytecodeCallable(dest, normalizeIRName(name))
  dest

proc genCreateArrayLit(
    runtime: Runtime,
    fn: Function,
    stmt: Statement,
    parentStmt: Option[Statement],
    exprStoreIn: Option[string],
) =
  let pos = runtime.realm.addrIdx
  runtime.ir.loadList(pos)
  if *stmt.storeIn:
    runtime.markLocal(fn, &stmt.storeIn)
  elif *parentStmt:
    assert(*exprStoreIn)
    runtime.markInternal(&parentStmt, &exprStoreIn)
  else:
    inc runtime.realm.addrIdx

  for child in stmt.calChildren:
    let childIdx = runtime.evalExpr(fn, child)
    runtime.ir.appendList(pos, childIdx)

proc genAtomHolder(
    runtime: Runtime, fn: Function, stmt: Statement, storeIn: string, parent: Statement
) =
  let index = runtime.loadIRAtom(stmt.atom)
  runtime.markInternal(parent, storeIn, index = some(index))
  inc runtime.realm.addrIdx

proc genFieldAccessHolder(
    runtime: Runtime, fn: Function, stmt: Statement, storeIn: string, parent: Statement
) =
  let index = runtime.resolveFieldAccess(
    fn,
    stmt,
    runtime.index(stmt.fieldAccessList.identifier, defaultParams(fn)),
    stmt.fieldAccessList,
  )
  runtime.markInternal(parent, storeIn, index = some(index))

proc genListIterator*(runtime: Runtime, fn: Function, stmt: Statement) =
  runtime.markLocal(fn, &stmt.iterStoresIn)
  runtime.generateBytecode(fn = fn, stmt = stmt.iterList)

proc genCopyFieldToVar*(runtime: Runtime, fn: Function, stmt: Statement) =
  let resolved = resolveFieldAccess(
    runtime,
    fn,
    stmt,
    runtime.index(stmt.cfvarField.identifier, defaultParams(fn)),
    stmt.cfvarField,
  )

  if *stmt.cfvarIdentDest:
    runtime.ir.copyAtom(
      source = resolved, dest = runtime.index(&stmt.cfvarIdentDest, defaultParams(fn))
    )
  elif *stmt.cfvarFieldDest:
    let (owner, field) = runtime.resolveFieldOwner(fn, stmt, &stmt.cfvarFieldDest)
    runtime.ir.writeField(owner, field, resolved)

proc genConstructObjectShort*(runtime: Runtime, fn: Function, stmt: Statement) =
  let index = runtime.realm.addrIdx
  runtime.markLocal(fn, &stmt.cosStoreIdent)

  runtime.ir.loadObject(index)

  for key, value in stmt.cosKVPairs:
    assert(value.kind in {AtomHolder, FunctionHolder})

    var valueIndex = runtime.index("undefined", defaultParams(fn))

    case value.kind
    of AtomHolder:
      valueIndex = runtime.loadIRAtom(value.atom)
    of FunctionHolder:
      value.function.name = generateLambdaName(runtime)
      value.function.unmangled = false

      let
        prevCachedIndex = runtime.ir.cachedIndex
        prevCurrModule = runtime.ir.currModule

      runtime.generateBytecodeForScope(
        scope = Scope(value.function), allocateConstants = false
      )
      runtime.ir.cachedIndex = prevCachedIndex
      runtime.ir.currModule = prevCurrModule
      runtime.ir.cachedModule = nil

      runtime.markInternal(stmt, value.function.name)
      valueIndex = runtime.realm.addrIdx - 1

      runtime.ir.loadBytecodeCallable(valueIndex, value.function.name)
    else:
      unreachable

    case key.kind
    of AtomHolder:
      case key.atom.kind
      of String:
        runtime.ir.writeField(index, &key.atom.getStr(), valueIndex)
      else:
        unreachable
    else:
      unreachable

proc evalExpr(runtime: Runtime, fn: Function, expr: Statement): uint =
  case expr.kind
  of AtomHolder:
    let idx = runtime.loadIRAtom(expr.atom)
    inc runtime.realm.addrIdx
    idx
  of IdentHolder:
    runtime.index(expr.ident, defaultParams(fn))
  of FieldAccessHolder:
    runtime.resolveFieldAccess(
      fn,
      expr,
      runtime.index(expr.fieldAccessList.identifier, defaultParams(fn)),
      expr.fieldAccessList,
    )
  of AccessField:
    let
      targetAddr =
        if *expr.accessTarget:
          runtime.evalExpr(fn, &expr.accessTarget)
        else:
          runtime.index(expr.identifier, defaultParams(fn))
      dest = runtime.allocTemp()

    runtime.ir.loadNull(dest)
    runtime.ir.resolveField(targetAddr, dest, @[expr.field])
    dest
  of AccessArrayIndex:
    let
      targetAddr =
        if *expr.arrAccTarget:
          runtime.evalExpr(fn, &expr.arrAccTarget)
        else:
          runtime.index(expr.arrAccIdent, defaultParams(fn))
      idxAddr =
        if *expr.arrAccIndex:
          runtime.evalExpr(fn, &expr.arrAccIndex)
        elif *expr.arrAccIdentIndex:
          runtime.index(&expr.arrAccIdentIndex, defaultParams(fn))
        else:
          unreachable
          0'u
      dest = runtime.allocTemp()

    runtime.ir.loadUndefined(dest)
    runtime.ir.resetArgs()
    runtime.ir.passArgument(targetAddr)
    runtime.ir.passArgument(idxAddr)
    runtime.ir.call("BALI_INDEX")
    runtime.ir.readRegister(dest, Register.ReturnValue)
    runtime.ir.zeroRetval()
    runtime.ir.resetArgs()
    dest
  of Call:
    let dest = runtime.allocTemp()
    runtime.ir.loadUndefined(dest)
    runtime.generateBytecode(fn, expr, ownerStmt = some(expr))
    runtime.ir.readRegister(dest, Register.ReturnValue)
    runtime.ir.zeroRetval()
    dest
  of ConstructObject:
    let dest = runtime.allocTemp()
    runtime.ir.loadUndefined(dest)
    runtime.genConstructObject(fn = fn, stmt = expr, internal = true)
    runtime.ir.readRegister(dest, Register.ReturnValue)
    runtime.ir.zeroRetval()
    dest
  of BinaryOp:
    let
      dest = runtime.allocTemp()
      prevStoreIn = expr.binStoreIn
    runtime.ir.loadUndefined(dest)
    expr.binStoreIn = none(string)
    runtime.markInternal(expr, "@expr", index = some(dest))
    runtime.genBinaryOp(
      fn = fn,
      stmt = expr,
      internal = true,
      parentStmt = some(expr),
      exprStoreIn = some("@expr"),
    )
    expr.binStoreIn = prevStoreIn
    dest
  of TernaryOp:
    let dest = runtime.allocTemp()
    runtime.ir.loadUndefined(dest)
    runtime.markInternal(expr, "@expr", index = some(dest))
    runtime.genTernaryOp(
      fn = fn,
      stmt = expr,
      internal = true,
      parentStmt = some(expr),
      exprStoreIn = some("@expr"),
    )
    dest
  of CreateArrayLiteral:
    let pos = runtime.allocTemp()
    runtime.ir.loadList(pos)
    for child in expr.calChildren:
      let childIdx = runtime.evalExpr(fn, child)
      runtime.ir.appendList(pos, childIdx)
    pos
  of DefineFunction:
    runtime.genDefineFunction(
      fn = fn, stmt = expr, parent = none(Statement), storeIn = none(string)
    )
  else:
    debugEcho expr.kind
    unreachable
    0'u

proc genDeclaration*(
    runtime: Runtime,
    fn: Function,
    stmt: Statement,
    internal: bool,
    ownerStmt: Option[Statement],
) =
  if stmt.declValue.kind == Call:
    runtime.genCallAndStoreResult(
      fn = fn,
      stmt = callAndStore(stmt.declIdent, stmt.declValue),
      ownerStmt = ownerStmt,
    )
    return

  let idx =
    case stmt.declValue.kind
    of AtomHolder:
      runtime.loadIRAtom(stmt.declValue.atom)
    of IdentHolder:
      let idx = runtime.allocTemp()
      runtime.ir.copyAtom(runtime.index(stmt.declValue.ident, defaultParams(fn)), idx)
      idx
    else:
      runtime.evalExpr(fn, stmt.declValue)

  if not internal:
    runtime.markLocal(fn, stmt.declIdent, index = some(idx))
  else:
    assert(*ownerStmt)
    if stmt.declValue.kind == AtomHolder:
      runtime.markInternal(&ownerStmt, stmt.declIdent)
    else:
      runtime.markInternal(&ownerStmt, stmt.declIdent, index = some(idx))

{.pop.}

proc generateBytecode(
    runtime: Runtime,
    fn: Function,
    stmt: Statement,
    internal: bool = false,
    ownerStmt: Option[Statement] = none(Statement),
    exprStoreIn: Option[string] = none(string),
    parentStmt: Option[Statement] = none(Statement),
    index: Option[uint] = none(uint),
) {.gcsafe.} =
  ## Given a statement `stmt` and its encompassing functional scope `fn` (which can be a plain scope as well),
  ## generate the bytecode for that statement.
  ## **NOTE**: This function can be _HIGHLY_ recursive in nature and has side effects*
  case stmt.kind
  of Declaration:
    runtime.genDeclaration(
      fn = fn, stmt = stmt, internal = internal, ownerStmt = ownerStmt
    )
  of Call:
    runtime.genCall(fn = fn, stmt = stmt, internal = internal, ownerStmt = ownerStmt)
  of ReturnFn:
    runtime.genReturnFn(fn = fn, stmt = stmt)
  of CallAndStoreResult:
    runtime.genCallAndStoreResult(fn = fn, stmt = stmt, ownerStmt = ownerStmt)
  of ConstructObject:
    runtime.genConstructObject(fn = fn, stmt = stmt, internal = internal)
  of ReassignVal:
    runtime.genReassignVal(fn = fn, stmt = stmt)
  of ThrowError:
    runtime.genThrowError(fn = fn, stmt = stmt, internal = internal)
  of BinaryOp:
    runtime.genBinaryOp(
      fn = fn,
      stmt = stmt,
      internal = internal,
      parentStmt = parentStmt,
      exprStoreIn = exprStoreIn,
    )
  of IfStmt:
    runtime.genIfStmt(fn = fn, stmt = stmt)
  of CopyValMut:
    runtime.genCopyValMut(fn = fn, stmt = stmt)
  of CopyValImmut:
    runtime.genCopyValImmut(fn = fn, stmt = stmt)
  of WhileStmt:
    runtime.genWhileStmt(fn = fn, stmt = stmt)
  of Increment:
    runtime.genIncrement(fn = fn, stmt = stmt)
  of Decrement:
    runtime.genDecrement(fn = fn, stmt = stmt)
  of Break:
    runtime.genBreak(fn = fn, stmt = stmt)
  of Waste:
    runtime.genWaste(fn = fn, stmt = stmt)
  of AccessField:
    runtime.genAccessField(
      fn = fn, stmt = stmt, parentStmt = parentStmt, storeIn = exprStoreIn
    )
  of AccessArrayIndex:
    runtime.genAccessArrayIndex(
      fn = fn, stmt = stmt, storeIn = exprStoreIn, parentStmt = parentStmt
    )
  of IndexAssignment:
    runtime.genIndexAssignment(fn = fn, stmt = stmt)
  of TernaryOp:
    runtime.genTernaryOp(fn = fn, stmt = stmt)
  of ForLoop:
    runtime.genForLoop(fn = fn, stmt = stmt)
  of TryCatch:
    runtime.genTryClause(fn = fn, stmt = stmt)
  of CompoundAssignment:
    runtime.genCompoundAsgn(fn = fn, stmt = stmt)
  of DefineFunction:
    discard runtime.genDefineFunction(
      fn = fn, stmt = stmt, parent = parentStmt, storeIn = exprStoreIn
    )
  of CreateArrayLiteral:
    runtime.genCreateArrayLit(
      fn = fn, stmt = stmt, parentStmt = parentStmt, exprStoreIn = exprStoreIn
    )
  of AtomHolder:
    if *exprStoreIn and *parentStmt:
      runtime.genAtomHolder(
        fn = fn, stmt = stmt, storeIn = &exprStoreIn, parent = &parentStmt
      )
  of FieldAccessHolder:
    let targetParent = if *ownerStmt: ownerStmt else: parentStmt
    if *exprStoreIn and *targetParent:
      runtime.genFieldAccessHolder(
        fn = fn, stmt = stmt, storeIn = &exprStoreIn, parent = &targetParent
      )
  of ListIterator:
    runtime.genListIterator(fn = fn, stmt = stmt)
  of CopyFieldToVar:
    runtime.genCopyFieldToVar(fn = fn, stmt = stmt)
  of ConstructObjectShorthand:
    runtime.genConstructObjectShort(fn = fn, stmt = stmt)
  else:
    discard

  runtime.vm.sourceMap[fn.name][runtime.ir.cachedIndex] =
    (message: stmt.source, line: stmt.line)

proc loadArgumentsOntoStack(runtime: Runtime, fn: Function) =
  let thisAddr = runtime.realm.addrIdx
  runtime.markLocal(fn, ThisIdent)
  runtime.ir.readRegister(thisAddr, Register.This)

  for i, arg in fn.arguments:
    runtime.markLocal(fn, arg)
    runtime.ir.readRegister(
      runtime.index(arg, defaultParams(fn)), i.uint, Register.CallArgument
    )

  runtime.ir.resetArgs()

proc generateBytecodeForScope(
    runtime: Runtime, scope: Scope, allocateConstants: bool = true
) {.gcsafe.} =
  let
    fn =
      try:
        Function(scope)
      except ObjectConversionDefect:
        Function(
          name: EntryPointName,
          arguments: newSeq[string](0),
          prev: scope.prev,
          children: scope.children,
          stmts: scope.stmts,
          unmangled: true,
        )
    name = fn.name

  if not runtime.realm.clauses.contains(name):
    runtime.realm.clauses.add(name)
    runtime.ir.newModule(
      if likely(not fn.unmangled):
        name.normalizeIRName()
      else:
        name
    )

  for child in scope.children:
    let clause =
      try:
        Function(child).name
      except ObjectConversionDefect:
        newString(0)

    if clause.len > 0:
      runtime.markGlobal(clause)
      let fnIndex = runtime.realm.addrIdx - 1
      runtime.ir.loadBytecodeCallable(fnIndex, clause)

  runtime.irHints.generatedClauses &= name
  runtime.vm.sourceMap[name] = initTable[uint, tuple[message: string, line: uint]]()

  if name != EntryPointName:
    runtime.loadArgumentsOntoStack(fn)
  else:
    if allocateConstants:
      constants.generateStdIr(runtime)
      inc runtime.realm.addrIdx

      for i, typ in runtime.types:
        let idx = runtime.realm.addrIdx
        runtime.markGlobal(typ.name)
        runtime.types[i].singletonId = idx

  for i, stmt in scope.stmts:
    runtime.generateBytecode(fn, stmt, index = some(uint(i)))

  for child in scope.children:
    runtime.generateBytecodeForScope(child)

proc computeTypeof*(runtime: Runtime, atom: JSValue): string =
  ## Compute the type of an atom.
  case atom.kind
  of String:
    "string"
  of Integer, Float:
    "number"
  of Null, Sequence:
    "object"
  of Object:
    if runtime.isA(atom, JSString):
      return "string"

    if runtime.isA(atom, JSBigInt):
      return "bigint"

    if runtime.isA(atom, JSFunction):
      return "function"

    "object"
  of Boolean:
    "boolean"
  of BigInteger:
    "bigint"
  of Undefined:
    "undefined"
  of NativeCallable, BytecodeCallable:
    "function"
  else:
    unreachable
    newString(0)

proc generateInternalIR*(runtime: Runtime) =
  ## Generate the internal functions needed by Bali to work properly.
  runtime.vm[].registerBuiltin(
    "BALI_TYPEOF",
    proc(op: Operation) =
      inc runtime.statTypeofCalls
      let atom = runtime.argument(1)
      assert(*atom, "BUG: Atom was empty when calling BALI_TYPEOF_INTERNAL!")
      ret runtime.computeTypeof(&atom)
    ,
  )

  runtime.vm[].registerBuiltin(
    "BALI_INDEX",
    proc(op: Operation) =
      let
        atom = runtime.argument(1)
        index = runtime.argument(2)

      assert(*atom, "BUG: Atom was empty when calling BALI_INDEX_INTERNAL!")

      let
        target = &atom
        indexValue = &index

      case target.kind
      of MAtomKind.Sequence:
        let idx = int(&(&index).getNumeric())
        var vec = (&atom).sequence
        if idx < 0 or idx > vec.len - 1:
          ret undefined(runtime)

        ret vec[idx]
      of MAtomKind.Object:
        if runtime.isA(target, JSArray):
          ret runtime.indexArray(target, uint32(&getNumeric(indexValue)))

        ret runtime.getProperty(target, runtime.ToString(indexValue))
      else:
        ret undefined(runtime)
    ,
  )

  runtime.vm[].registerBuiltin(
    BuiltinInvokeCtor,
    proc(op: Operation) =
      let
        typ = &runtime.argument(1)
        ctor = typ.tagged("Construct")

      runtime.vm.registers.callArgs.delete(0)

      if !ctor:
        runtime.typeError("Type has no constructor")
        return

      runtime.vm[].invoke(&ctor)
      runtime.vm.registers.callArgs.reset(),
  )

  runtime.vm[].registerBuiltin(
    "BALI_EQUATE_ATOMS",
    proc(op: Operation) =
      let
        a = &runtime.argument(1)
        b = &runtime.argument(2)

      runtime.vm.registers.callArgs.reset()

      let res = runtime.isLooselyEqual(a, b)
      if not res:
        runtime.vm.currIndex += 1
    ,
  )

  runtime.vm[].registerBuiltin(
    "BALI_EQUATE_ATOMS_STRICT",
    proc(op: Operation) =
      let
        a = &runtime.argument(1)
        b = &runtime.argument(2)

      runtime.vm.registers.callArgs.reset()

      let res = runtime.isStrictlyEqual(a, b)
      if not res:
        runtime.vm.currIndex += 1
    ,
  )

  if runtime.opts.insertDebugHooks:
    runtime.defineFn(
      "baliGC_Dump",
      proc() =
        echo GC_getStatistics()
      ,
    )

    runtime.generateDescribeFnCode()

    runtime.defineFn(
      "baliGC_FullCollect",
      proc() =
        GC_fullCollect(),
    )

    runtime.defineFn(
      "baliGC_PartialCollect",
      proc() =
        let limit = &(&runtime.argument(1)).getInt()
        GC_partialCollect(limit),
    )

    runtime.defineFn(
      "baliVM_IsCompiled",
      proc() =
        ret runtime.vm.runningCompiled
      ,
    )

export types
