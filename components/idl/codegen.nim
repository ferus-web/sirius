## IDL -> Nim wrapper/stub generator
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, strutils, strformat]
import components/aux/pretty
import pkg/[shakar, webidl2nim/ast]

type
  InterfaceState {.pure.} = enum
    Name
    Ancester
    Members

  ConstStmtState {.pure.} = enum
    Name
    Type
    Value

  ValueKind* {.pure.} = enum
    UnsignedShort
    UnsignedLong
    Boolean
    Byte
    Octet
    Short
    Long
    LongLong
    UnsignedLongLong
    DOMString
    Any

  Attribute = object
    name*: string
    kind*: ValueKind

  Constant = object
    name*: string
    kind*: ValueKind

    u16*: uint16
    i16*: int16
    u32*: uint32
    i32*: int32
    u64*: uint64
    i64*: int64
    i8*: int8
    u8*: uint8
    boolean*: bool

    str*: string

  Arg = object
    name*: string
    kind*: ValueKind

    optional*: bool
    defaultValue*: Option[Constant]

  Op = object
    returnType*: ValueKind
    name*: string
    arguments*: seq[Arg]

  Interface = object
    name*: string
    ancester*: Option[string]
    constants*: seq[Constant]
    attributes*: seq[Attribute]
    ops*: seq[Op]

func getTypeFromNodes(typeNode: Node): Option[ValueKind] =
  assert(typeNode.kind == Type)

  let idents = typeNode.sons[0]
  if idents.kind == Union:
    # don't even joke lad.
    return some(ValueKind.Any)

  let typ0 =
    if idents.kind == Idents:
      idents.sons[0].strVal
    else:
      idents.strVal

  if typ0 == "unsigned":
    assert(idents.sons.len > 1)

    let typ = idents.sons[1].strVal
    if typ == "short":
      return some(ValueKind.UnsignedShort)
    elif typ == "long":
      if idents.sons.len > 2 and idents.sons[1].strVal == "long":
        return some(ValueKind.UnsignedLongLong)

      return some(ValueKind.UnsignedLong)
  elif typ0 == "DOMString":
    return some(ValueKind.DOMString)
  elif typ0 == "long":
    if idents.sons.len == 1:
      return some(ValueKind.Long)

    let typ = idents.sons[1].strVal
    assert(typ == "long")
    return some(ValueKind.LongLong)
  elif typ0 == "short":
    return some(ValueKind.Short)
  elif typ0 == "octet":
    return some(ValueKind.Octet)
  elif typ0 == "byte":
    return some(ValueKind.Byte)
  elif typ0 == "boolean":
    return some(ValueKind.Boolean)
  else:
    return some(ValueKind.Any)

func asgnNodeAsValue(node: Node, constant: var Constant) =
  case constant.kind
  of ValueKind.UnsignedShort:
    constant.u16 = uint16(node.intVal)
  of ValueKind.UnsignedLong:
    constant.u32 = uint32(node.intVal)
  of ValueKind.UnsignedLongLong:
    constant.u64 = uint32(node.intVal)
  of ValueKind.Boolean:
    constant.boolean = node.boolVal
  else:
    unreachable

func genConstStmt(iface: var Interface, def: Node) =
  assert(def.kind == IdentDefs)

  var
    state = ConstStmtState.Name
    constant: Constant

  for son in def.sons:
    case state
    of ConstStmtState.Name:
      if son.kind == Ident:
        constant.name = son.strVal
        state = ConstStmtState.Type
    of ConstStmtState.Type:
      if son.kind == Type:
        constant.kind = &getTypeFromNodes(son)
        state = ConstStmtState.Value
    of ConstStmtState.Value:
      asgnNodeAsValue(son, constant)

  iface.constants &= ensureMove(constant)

func genArguments(list: Node): seq[Arg] =
  var res = newSeqOfCap[Arg](list.sons.len)

  assert(list.kind == ArgumentList)
  for son in list.sons:
    assert(son.kind == Argument)

    let argument = son.sons[0]
    assert(argument.kind in {OptionalArgument, SimpleArgument}, $argument.kind)

    let name = argument.sons[0].sons[0].strVal
    let typ = &getTypeFromNodes(argument.sons[0].sons[1])

    var arg = Arg(name: name, kind: typ, optional: argument.kind == OptionalArgument)
    if argument.sons[0].sons.len > 2 and argument.sons[0].sons[2].kind != Empty:
      var defaultValue = Constant(kind: typ)
      asgnNodeAsValue(argument.sons[0].sons[2], defaultValue)

      arg.defaultValue = some(ensureMove(defaultValue))

    res &= ensureMove(arg)

  ensureMove(res)

func genOp(iface: var Interface, node: Node) =
  assert(node.kind == RegularOperation)

  var op = Op(
    name: node.sons[0].strVal,
    returnType: &getTypeFromNodes(node.sons[1]),
    arguments: genArguments(node.sons[2]),
  )

  iface.ops &= ensureMove(op)

func genInterfaceMember(iface: var Interface, member: Node) =
  case member.kind
  of ConstStmt:
    genConstStmt(iface, member.sons[0])
  of Operation:
    genOp(iface, member.sons[0])
  of Attribute:
    debugecho "attr"
  of Readonly:
    debugecho "readonly attr"
  of Constructor:
    debugecho "constructor"
  else:
    unreachable

func pascalCase(ident: string): string =
  var buffer = newStringOfCap(ident.len) # worst case: we have the same number of bytes
  var i = 0
  let size = ident.len

  while i < size:
    let c = ident[i]
    if i == 0:
      buffer &= c.toUpperAscii()
      inc i
      continue

    if c == '_':
      if i == size - 1:
        inc i
        continue

      inc i
      buffer &= ident[i].toUpperAscii()
    else:
      buffer &= c.toLowerAscii()

    inc i

  ensureMove(buffer)

func convertValueKind(kind: ValueKind): string =
  case kind
  of Short: "uint16"
  of Long: "uint32"
  of UnsignedShort: "uint16"
  of UnsignedLong: "uint32"
  of Boolean: "bool"
  of Byte: "int8"
  of Octet: "uint8"
  of LongLong: "int64"
  of UnsignedLongLong: "uint64"
  of DOMString: "string"
  of Any: "JSValue"

func emitConstant(constant: Constant): string =
  case constant.kind
  of Short:
    $constant.i16
  of Long:
    $constant.i32
  of UnsignedShort:
    $constant.u16
  of UnsignedLong:
    $constant.u32
  of Boolean:
    $constant.boolean
  of Byte:
    $constant.i8
  of Octet:
    $constant.u8
  of LongLong:
    $constant.i64
  of UnsignedLongLOng:
    $constant.u64
  of DOMString:
    $constant.str
  of Any:
    "undefined(runtime)"

func genInterface(node: Node, buffer: var string) =
  var state = InterfaceState.Name
  var iface: Interface

  for son in node.sons:
    case state
    of InterfaceState.Name:
      if son.kind == Ident:
        iface.name = son.strVal
        state = InterfaceState.Ancester
    of InterfaceState.Ancester:
      if son.kind == Ident:
        iface.ancester = some(son.strVal)

      state = InterfaceState.Members
    of InterfaceState.Members:
      if son.kind == InterfaceMember:
        genInterfaceMember(iface, son.sons[0])

  buffer &= &"type {iface.name}* = object"
  if *iface.ancester:
    buffer &= &" of {&iface.ancester}"

  buffer &= '\n'

  if iface.constants.len > 0:
    buffer &= "\nconst\n"
    for constant in iface.constants:
      buffer &=
        &"  {pascalCase(constant.name)}*: {convertValueKind(constant.kind)} = {emitConstant(constant)}\n"

  for op in iface.ops:
    buffer &= &"\nproc {op.name}(rt: Runtime, this: JSValue"

    for arg in op.arguments:
      buffer &= &", {arg.name}: {convertValueKind(arg.kind)}"

    buffer &= "): JSValue =\n"
    buffer &= &"  warn \"IMPLEMENTME: {iface.name}::{op.name}()\""

    for arg in op.arguments:
      buffer &=
        &", {arg.name} = " & (
          if arg.kind == ValueKind.Any:
            &"rt.ToString({arg.name})"
          else:
            arg.name
        )

    buffer &= "\n  undefined(rt)"

    buffer &= "\n"

  buffer &= "\nproc generateBindings*(runtime: Runtime) =\n"
  buffer &= &"  runtime.registerType(\"{iface.name}\", {iface.name})"

  for op in iface.ops:
    buffer &=
      &"""

  runtime.definePrototypeFn(
    {iface.name},
    "{op.name}",
    proc(this: JSValue) =
"""

    const InnerIndent = "      "

    for i, arg in op.arguments:
      buffer &= &"{InnerIndent}let {arg.name} = "

      let argumentGetCall = &"&runtime.argument({i + 1}, required = {not arg.optional})"

      case arg.kind
      of ValueKind.Any:
        buffer &= argumentGetCall
      of ValueKind.Short:
        buffer &= &"int16(runtime.ToNumeric({argumentGetCall}))"
      of ValueKind.Long:
        buffer &= &"int32(runtime.ToNumeric({argumentGetCall}))"
      of ValueKind.UnsignedShort:
        buffer &= &"uint16(runtime.ToNumeric({argumentGetCall}))"
      of ValueKind.UnsignedLong:
        buffer &= &"uint32(runtime.ToNumeric({argumentGetCall}))"
      of ValueKind.Boolean:
        buffer &= &"&getBool({argumentGetCall})"
      of ValueKind.Byte:
        buffer &= &"int8(runtime.ToNumeric({argumentGetCall}))"
      of ValueKind.Octet:
        buffer &= &"uint8(runtime.ToNumeric({argumentGetCall}))"
      of ValueKind.LongLong:
        buffer &= &"int64(runtime.ToNumeric({argumentGetCall}))"
      of ValueKind.UnsignedLongLong:
        buffer &= &"uint64(runtime.ToNumeric({argumentGetCall}))"
      of ValueKind.DOMString:
        buffer &= &"runtime.ToString({argumentGetCall})"

      buffer &= '\n'

    buffer &= &"{InnerIndent}ret {op.name}(rt = runtime, this = this"
    for arg in op.arguments:
      buffer &= &", {arg.name} = {arg.name}"
    buffer &= ")\n"

    buffer &= "  )\n"

proc generateWrapper*(tree: seq[Node]): string =
  var buffer = newStringOfCap(4096)
  buffer &= "import components/js/runtime/prelude\n"
  buffer &= "import pkg/[chronicles, shakar]\n\n"
  buffer &= """logScope:
  topics = "stub" # TODO: Replace this with something more appropriate!

"""

  for node in tree:
    case node.kind
    of Interface:
      genInterface(node, buffer)
    of Dictionary:
      discard
    else:
      unreachable

  ensureMove(buffer)
