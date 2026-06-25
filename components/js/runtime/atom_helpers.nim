## Atom functions

import std/[options, tables]
import components/js/runtime/vm/atom, components/js/runtime/vm/heap/manager

type Hidden*[T: ref object | ptr object] = distinct T
  ## Hidden state that you do not wish for JavaScript code to access.

{.push warning[UnreachableCode]: off, inline.}

func isUndefined*(atom: MAtom | JSValue): bool =
  atom.kind == Undefined

func isObject*(atom: JSValue): bool =
  atom.kind == Object

func isNull*(atom: JSValue): bool =
  atom.kind == Null

func isNumber*(atom: JSValue): bool =
  atom.kind == Integer or atom.kind == Float

func isBigInt*(atom: JSValue): bool =
  atom.kind == BigInteger

proc `[]=`*(atom: JSValue, name: string, value: sink JSValue) =
  if atom.kind != Object:
    raise newException(ValueError, $atom.kind & " does not have field access methods")

  if not atom.objFields.contains(name):
    atom.objValues &= ensureMove(value)
    atom.objFields[name] =
      Property(isAccessor: false, index: cast[uint32](atom.objValues.len) - 1'u32)
  elif not atom.objFields[name].isAccessor:
    atom.objValues[atom.objFields[name].index] = ensureMove(value)
  else:
    raise newException(
      ValueError, "Cannot set field on property '" & name & "' as it is an accessor."
    )

proc setHiddenField*(atom: JSValue, name: string, value: sink JSValue) =
  if atom.kind != Object:
    raise newException(ValueError, $atom.kind & " does not have field access methods")

  atom.objValues &= ensureMove(value)
  atom.objHiddenFields[name] = cast[uint32](atom.objValues.len) - 1'u32

proc getHiddenField*(atom: JSValue, name: string): Option[JSValue] =
  if name notin atom.objHiddenFields:
    return none(JSValue)

  some(atom.objValues[atom.objHiddenFields[name]])

proc createField*(atom: JSValue, field: string, heap: HeapManager) =
  atom[field] = undefined(heap)

proc contains*(atom: JSValue, name: string): bool =
  atom.objFields.contains(name)

proc tagged*(atom: JSValue, tag: string): Option[JSValue] =
  getHiddenField(atom, tag)

proc tag*(atom: JSValue, tag: string, value: JSValue) =
  atom.setHiddenField(tag, value)

{.pop.}
