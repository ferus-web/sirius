## "Wrapping" convenience functions that can turn various types into their
## Bali JavaScript value representations.
## **NOTE**: All of the functions below are allocating memory on the Bali GC heap and can be nil in the case of an OOM!
import std/[tables]
import
  components/js/runtime/vm/atom,
  components/js/runtime/atom_helpers,
  components/js/stdlib/types/std_string_type,
  components/js/runtime/types,
  pkg/shakar

proc wrap*(runtime: Runtime, val: SomeInteger | string | float | bool): JSValue =
  when val is SomeInteger:
    return integer(runtime.realm.heap, val.int)

  when val is bool:
    return boolean(runtime.realm.heap, val)

  when val is string:
    return runtime.newJSString(val)

  when val is float:
    return floating(runtime.realm.heap, val)

proc wrap*[T: not JSValue](runtime: Runtime, val: openArray[T]): JSValue =
  var vec = sequence(runtime.realm.heap, newSeqOfCap[MAtom](val.len - 1))

  for v in val:
    vec.sequence &= runtime.wrap(v)[]

  vec

proc wrap*[T: ref object | ptr object](runtime: Runtime, hidden: Hidden[T]): JSValue =
  # just store these as 64 bit signed ints
  integer(runtime.realm.heap, cast[int64](hidden))

func wrap*[V: JSValue | MAtom](runtime: Runtime, atom: V): V {.inline.} =
  atom

proc wrap*[A, B](runtime: Runtime, val: Table[A, B]): JSValue =
  var atom = obj(runtime.realm.heap)
  for k, v in val:
    atom[$k] = runtime.wrap(v)

  atom

proc wrap*[T: object](runtime: Runtime, obj: T): JSValue =
  let mObj = atom.obj(runtime.realm.heap)

  for name, field in obj.fieldPairs:
    when field is FieldAccessor:
      runtime.setFieldAccessor(mObj, name, field)
    elif field is Hidden:
      mObj.setHiddenField(name, runtime.wrap(field))
    else:
      mObj[name] = runtime.wrap(field)

  mObj

proc wrap*[T: object](runtime: Runtime, dest: JSValue, obj: T) =
  for name, field in obj.fieldPairs:
    when field is Hidden:
      setHiddenField(dest, name, runtime.wrap(field))
    elif field is FieldAccessor:
      runtime.setFieldAccessor(dest, name, field)
    else:
      dest[name] = runtime.wrap(field)

proc wrap*(runtime: Runtime, val: seq[JSValue]): JSValue =
  var atoms = newSeq[MAtom](val.len)

  for i, value in val:
    atoms[i] = val[i][]

  sequence(runtime.realm.heap, ensureMove(atoms))

proc wrap*[T](runtime: Runtime, val: seq[T]): JSValue =
  var atoms = newSeq[MAtom](val.len)

  for i, value in val:
    atoms[i] = runtime.wrap(value)[]

  sequence(runtime.realm.heap, ensureMove(atoms))

template `[]=`*[T: not JSValue](atom: JSValue, name: string, value: T) =
  atom[name] = runtime.wrap(value)

proc tag*[T](runtime: Runtime, atom: JSValue, tag: string, value: T) =
  atom.setHiddenField(runtime.wrap(atom))
