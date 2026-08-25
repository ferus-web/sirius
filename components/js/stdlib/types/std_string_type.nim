## Basic types for `JSString`.
## Separated from the String prototype functions to prevent circular dependencies. 

import
  components/js/runtime/vm/atom,
  components/js/runtime/atom_helpers,
  components/js/runtime/[construction, types],
  components/js/runtime/vm/heap/manager,
  components/impure/simdutf
import components/unicode/utf16view
import pkg/shakar

type JSString* = object
  internal*: Hidden[ptr UTF16View]
  length*: uint64

proc newJSString*(rt: Runtime, view: ptr UTF16View): JSValue =
  let str = rt.createObjFromType(JSString)

  str["length"] = integer(rt, int(view.size))
  str.setHiddenField("internal", integer(rt, cast[int64](view)))

  str

proc newJSString*(rt: Runtime, native: string): JSValue =
  ## Given a native string, turn it into a `JSString` allocated on the heap.]

  # TODO: Can we eventually implement fat strings where we don't allocate the entire UTF16View and stuff, and just a pointer to u16(s) and there's a one byte tag at the beginning to tell whether it's a full UTF16View or that?
  let
    size = cast[uint64](native.len)
    sizeUtf16 =
      if size > 0:
        simdutf.utf16LengthFromUtf8(native[0].addr, size)
      else:
        0'u64

  let view =
    cast[ptr UTF16View](rt.realm.heap.allocate(cast[uint64](sizeof(UTF16View))))
  view.data =
    cast[ptr uint16](rt.realm.heap.allocate(cast[uint64](sizeof(uint16)) * sizeUtf16))

  if size > 0:
    discard simdutf.convertUtf8ToUtf16(native[0].addr, size, view.data)

  cast[ptr UncheckedArray[uint16]](view.data)[sizeUtf16] = 0'u16
  view.size = sizeUtf16

  newJSString(rt, view)

proc toNativeString*(str: JSValue): string =
  ## Given a `JSValue`, assuming it is a proper `JSString`, convert it into its native UTF-8 string representation.
  cast[ptr UTF16View](&getInt(&getHiddenField(str, "internal")))[].toUTF8()
