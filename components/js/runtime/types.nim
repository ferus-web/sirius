## Runtime types
##
## Copyright (C) 2024-2026 Trayambak Rai (xtrayambak at disroot dot org)

import std/[deques, monotimes, options, hashes, logging, sugar, tables, times]
import components/js/runtime/vm/ir/generator
import components/js/runtime/vm/prelude
import components/js/grammar/prelude
import components/js/runtime/[atom_obj_variant, atom_helpers, normalize]
import components/js/runtime/vm/heap/manager
import pkg/shakar

type
  NativeFunction* = proc() {.gcsafe.}
  NativePrototypeFunction* = proc(value: JSValue) {.gcsafe.}
  NativeGetterFunction* = NativePrototypeFunction
  NativeSetterFunction* = proc(this: JSValue, value: JSValue) {.gcsafe.}

  FieldAccessor* = ref object
    getter*: NativeGetterFunction
    setter*: NativeSetterFunction

  ValueKind* = enum
    vkGlobal
    vkLocal
    vkInternal ## or immediate

  IndexParams* = object
    priorities*: seq[ValueKind] = @[vkLocal, vkGlobal]

    fn*: Option[Function]
    stmt*: Option[Statement]

  Value* = object
    index*: uint
    identifier*: string
    case kind*: ValueKind
    of vkLocal:
      ownerFunc*: Hash
    of vkInternal:
      ownerStmt*: Hash
    else:
      discard

  ExperimentOpts* = object

  CodegenOpts* = object
    elideLoops*: bool = true
    loopAllocationEliminator*: bool = true
    aggressivelyFreeRetvals*: bool = false
    deadCodeElimination*: bool = true
    jitCompiler*: bool = true

  JITOpts* = object
    madhyasthalDumpIRFor*: seq[string]

  InterpreterOpts* = object
    test262*: bool = false
    repl*: bool = false
    dumpBytecode*: bool = false
    insertDebugHooks*: bool = false
      ## Allow some calls from JS-land that expose the engine's internals to it.

    codegen*: CodegenOpts
    experiments*: ExperimentOpts
    jit*: JITOpts

  JSType* = object
    name*: string
    constructor*: NativeFunction
    members*: Table[string, AtomOrFunction[NativeFunction]]
    prototypeFunctions*: Table[string, NativePrototypeFunction]
      ## Functions inherited by each object that derives from this type
    singletonId*: uint

    proto*: Hash

  IRLabel* = object
    start*, dummy*, ending*: uint

  IRHints* = object
    breaksGeneratedAt*: seq[uint]
    generatedClauses*: seq[string]
      ## FIXME: This is a horrible fix for the double-clause codegen bug!

  ConsoleLevel* {.pure.} = enum
    Debug
    Error
    Info
    Log
    Trace
    Warn

  TaskFlag* {.pure, size: sizeof(uint8).} = enum
    Immortal = 0

  Task* = object
    callback*: JSValue
    delay*: Duration
    flags*: set[TaskFlag]

    deadline*: MonoTime

  DeathCallback* = proc(vm: Interpreter) {.gcsafe.}
  ConsoleDelegate* = proc(level: ConsoleLevel, msg: string) {.gcsafe.}

  Realm* = ref object
    addrIdx*: uint
    values*: seq[Value]
    clauses*: seq[string]

    heap*: HeapManager

    constantsGenerated*: bool = false
    registeredEcmaTypes*: bool = false

  RuntimeStats* = object
    atomsAllocated*: uint ## How many atoms have been allocated so far?
    bytecodeSize*: uint ## How many kilobytes is the bytecode?
    breaksGenerated*: uint ## How many breaks did the codegen phase generate?
    vmHasHalted*: bool ## Has execution ended?
    fieldAccesses*: uint ## How many times has a field-access occurred?
    typeofCalls*: uint ## How many times has a typeof call occured?
    clausesGenerated*: uint ## How many clauses did the codegen phase generate?

    numAllocations*, numDeallocations*: uint
      ## How many allocations/deallocations happened during execution?

  Runtime* = ref object
    ast*: AST
    ir*: IRGenerator
    vm*: ptr Interpreter
    opts*: InterpreterOpts

    irHints*: IRHints
    test262*: Test262Opts

    statFieldAccesses, statTypeofCalls: uint
    allocStatsStart*: AllocStats

    types*: seq[JSType]

    deathCallback*: DeathCallback
    consoleDelegate*: ConsoleDelegate
    rng*: uint64

    realm*: Realm

    macrotaskQueue*: Deque[Task]

proc newRealm*(): Realm {.inline.} =
  Realm(heap: initHeapManager())

{.push warning[UnreachableCode]: off.}
proc setExperiment*(opts: var ExperimentOpts, name: string, value: bool): bool =
  ## Enable/disable an experimental Bali feature using its string flag (`name`).
  ## This function returns `true` if the operation succeeds, and `false` if
  ## the experiment is not recognized.
  case name
  else:
    warn "Unrecognized experiment \"" & name & "\"!"
    return false

  info "Enabling experiment \"" & name & '"'
  true

{.pop.}

proc getMethods*(
    runtime: Runtime, proto: Hash
): Table[string, NativePrototypeFunction] {.inline.} =
  for typ in runtime.types:
    if typ.proto == proto:
      var fns: Table[string, NativeFunction]
      #for name, member in typ.members:
      #  if member.isFn: fns[name] = member.fn()
      return typ.prototypeFunctions

  raise newException(KeyError, "No such type with proto hash: " & $proto & " exists!")

proc setupAtom*(runtime: Runtime, typ: JSType, value: JSValue) =
  ## Set up all properties and methods for a value off of a provided type.
  for name, member in typ.members:
    if member.isAtom():
      let idx = cast[uint32](value.objValues.len)
      value.objValues &= undefined(runtime.realm.heap)

      if member.hidden:
        value.objHiddenFields[name] = idx
      else:
        value.objFields[name] = Property(
          isAccessor: false,
          index: idx,
          descriptors: {
            FieldDescriptor.Writable, FieldDescriptor.Enumerable,
            FieldDescriptor.Configurable,
          },
        )

  for name, protoFn in typ.prototypeFunctions:
    capture name, protoFn:
      value[name] = nativeCallable(
        runtime.realm.heap,
        proc() =
          typ.prototypeFunctions[name](value),
      )

  value.tag("bali_object_type", integer(runtime.realm.heap, typ.proto.int))

proc createAtom*(runtime: Runtime, typ: JSType): JSValue =
  ## Create an atom (object) based off of a provided type.
  ## All fields of the provided `typ` are initialized in the object with `undefined`.
  ## The object will also gain an internal Bali-specific data slot/tag called `bali_object_type` which helps the engine
  ## in determining what type this object belongs to. It also attaches all the prototype functions needed.
  ##
  ## **This value will be allocated via Bali's internal garbage collector. Don't unnecessarily call this or else you might trigger a GC collection sweep.**
  let atom = obj(runtime.realm.heap)
  setupAtom(runtime, typ, atom)

  atom

proc createObjFromType*[T](runtime: Runtime, typ: typedesc[T]): JSValue =
  for etyp in runtime.types:
    if etyp.proto == hash($typ):
      return runtime.createAtom(etyp)

  raise newException(ValueError, "No such registered type: `" & $typ & '`')

proc defaultParams*(fn: Function): IndexParams {.inline.} =
  IndexParams(fn: some fn)

proc globalIndex*(): IndexParams {.inline.} =
  IndexParams(priorities: @[vkGlobal])

proc internalIndex*(stmt: Statement): IndexParams {.inline.} =
  IndexParams(priorities: @[vkInternal], stmt: some stmt)

proc markInternal*(
    runtime: Runtime, stmt: Statement, ident: string, index: Option[uint] = none(uint)
) =
  var toRm: seq[int]
  for i, value in runtime.realm.values:
    {.cast(gcsafe).}:
      if value.kind == vkInternal and value.identifier == ident and
          hash(stmt) == value.ownerStmt:
        toRm &= i

  for rm in toRm:
    runtime.realm.values.del(rm)

  {.cast(gcsafe).}:
    let indexS =
      if *index:
        &index
      else:
        runtime.realm.addrIdx

    runtime.realm.values &=
      Value(kind: vkInternal, index: indexS, identifier: ident, ownerStmt: hash(stmt))

    info "Ident \"" & ident & "\" is being internally marked at index " & $indexS &
      " with statement hash: " & $hash(stmt)

  if !index:
    inc runtime.realm.addrIdx

proc markGlobal*(runtime: Runtime, ident: string, index: Option[uint] = none(uint)) =
  var toRm: seq[int]
  for i, value in runtime.realm.values:
    if value.kind == vkGlobal and value.identifier == ident:
      toRm &= i

  for rm in toRm:
    runtime.realm.values.del(rm)

  let idx =
    if *index:
      &index
    else:
      runtime.realm.addrIdx

  runtime.realm.values &= Value(kind: vkGlobal, index: idx, identifier: ident)

  info "Ident \"" & ident & "\" is being globally marked at index " &
    $runtime.realm.addrIdx

  inc runtime.realm.addrIdx

proc markLocal*(
    runtime: Runtime, fn: Function, ident: string, index: Option[uint] = none(uint)
) =
  var toRm: seq[int]
  for i, value in runtime.realm.values:
    if value.kind == vkLocal and value.ownerFunc == hash(fn) and
        value.identifier == ident:
      toRm &= i

  for rm in toRm:
    runtime.realm.values.del(rm)

  let idx =
    if *index:
      &index
    else:
      runtime.realm.addrIdx

  runtime.realm.values &=
    Value(kind: vkLocal, index: idx, identifier: ident, ownerFunc: hash(fn))

  info "Ident \"" & ident & "\" is being locally marked at index " &
    $runtime.realm.addrIdx

  inc runtime.realm.addrIdx

proc resolveVariable*(
    runtime: Runtime, ident: string, params: IndexParams, demangle: bool = false
): Option[uint] =
  for value in runtime.realm.values:
    for prio in params.priorities:
      if value.kind == vkGlobal and value.identifier == ident:
        return some(value.index)

      if value.kind != prio:
        continue

      let identMatch =
        if demangle:
          value.identifier.normalizeIRName == ident
        else:
          value.identifier == ident

      {.cast(gcsafe).}:
        let cond =
          case value.kind
          of vkGlobal:
            identMatch
          of vkLocal:
            assert *params.fn
            identMatch and value.ownerFunc == hash(&params.fn)
          of vkInternal:
            assert *params.stmt
            identMatch and value.ownerStmt == hash(&params.stmt)

      if cond:
        return some(value.index)

proc index*(
    runtime: Runtime,
    ident: string,
    params: IndexParams,
    demangle: bool = false,
    willHandleResolveFail: bool = false,
): uint {.gcsafe.} =
  let resolved = resolveVariable(runtime, ident, params, demangle)
  if !resolved:
    if not willHandleResolveFail:
      runtime.ir.throwReferenceError(ident)

    assert(ident != "undefined")
    return runtime.index("undefined", params)

  &resolved

proc loadIRAtom*(runtime: Runtime, atom: MAtom): uint =
  debug "codegen: loading atom with kind: " & $atom.kind
  case atom.kind
  of Integer:
    runtime.ir.loadInt(runtime.realm.addrIdx, atom)
    return runtime.realm.addrIdx
  of String:
    runtime.ir.loadStr(runtime.realm.addrIdx, atom)
    runtime.ir.resetArgs()
    runtime.ir.passMultipleArguments(
      @[runtime.index("String", globalIndex()), runtime.realm.addrIdx]
    )
    runtime.ir.call("BALI_ICTOR")
    runtime.ir.resetArgs()
    runtime.ir.readRegister(runtime.realm.addrIdx, Register.ReturnValue)
    runtime.ir.zeroRetval()
    return runtime.realm.addrIdx
  of Null:
    runtime.ir.loadNull(runtime.realm.addrIdx)
    return runtime.realm.addrIdx
  of Boolean:
    runtime.ir.loadBool(runtime.realm.addrIdx, atom)
    return runtime.realm.addrIdx
  of Object:
    if atom.isUndefined():
      runtime.ir.loadObject(runtime.realm.addrIdx)
      return runtime.realm.addrIdx
    else:
      unreachable # FIXME
  of Float:
    runtime.ir.loadFloat(runtime.realm.addrIdx, atom)
    return runtime.realm.addrIdx
  of Sequence:
    runtime.ir.loadList(runtime.realm.addrIdx)
    result = runtime.realm.addrIdx

    for item in atom.sequence:
      inc runtime.realm.addrIdx
      let idx = runtime.loadIRAtom(item)
      runtime.ir.appendList(result, idx)
  of Undefined:
    runtime.ir.loadUndefined(runtime.realm.addrIdx)
    return runtime.realm.addrIdx
  else:
    unreachable
