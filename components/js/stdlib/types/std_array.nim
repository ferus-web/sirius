## Array type implementation
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, math]
import
  components/js/runtime/[arguments, atom_helpers, types, wrapping, bridge, construction],
  components/js/stdlib/errors
import components/js/runtime/abstract/[coercion, equating, slots]
import pkg/shakar
import components/js/runtime/vm/atom

type JSArray* = object
  internal*: Hidden[JSValue]
  length*: uint32 # TODO: probably should use u64

proc ArrayCreate*(rt: Runtime, size: uint32): JSValue =
  let arrObj = rt.createObjFromType(JSArray)
  let internal = sequence(rt, newSeq[JSValue](size))
  for i in 0 ..< size:
    internal.sequence[i] = undefined(rt)

  arrObj.setHiddenField("internal", internal)
  arrObj["length"] = rt.wrap(size)

  arrObj
  # JSArray(internal: hidden(sequence(rt, newSeq[MAtom](size))), length: size)

proc getInternalSeq(arr: JSValue): JSValue =
  &getHiddenField(arr, "internal")

proc indexArray*(rt: Runtime, arr: JSValue, index: uint32): JSValue =
  let length = uint32(rt.ToNumber(arr.getSimpleProperty("length")))
  if index >= length:
    return undefined(rt)

  getInternalSeq(arr).sequence[index]

proc LengthOfArrayLike*(rt: Runtime, obj: JSValue): uint32 =
  ## 7.3.18 LengthOfArrayLike ( obj )
  # The abstract operation LengthOfArrayLike takes argument obj (an Object) and returns either a normal completion containing a non-negative integer or a throw completion. It returns the value of the "length" property of an array-like object. It performs the following steps when called:

  # 1. Return ℝ(? ToLength(? Get(obj, "length"))).
  uint32(rt.ToNumber(obj.getSimpleProperty "length"))

proc generateBindings*(runtime: Runtime) =
  runtime.registerType("Array", JSArray)
  runtime.defineConstructor(
    "Array",
    proc() =
      # 23.1.1.1 Array ( ...values )
      # This function performs the following steps when called:

      # TODO: Implement 1 and 2
      # 1. If NewTarget is undefined, let newTarget be the active function object; else let newTarget be NewTarget.
      # 2. Let proto be ? GetPrototypeFromConstructor(newTarget, "%Array.prototype%").
      # 3. Let numberOfArgs be the number of elements in values.
      let numberOfArgs = cast[uint32](runtime.argumentCount)

      if numberOfArgs == 0:
        # 4. If numberOfArgs = 0, return ! ArrayCreate(0, proto).
        ret ArrayCreate(runtime, 0)
      elif numberOfArgs == 1:
        # 5. If numberOfArgs = 1, then
        # a. Let len be values[0].
        let size = &runtime.argument(1, required = true)

        # b. Let array be ! ArrayCreate(0, proto).
        var arr = ArrayCreate(runtime, 0)
        let internal = &getHiddenField(arr, "internal")

        var intLen: uint32

        # c. If len is not a Number, then
        # TODO: Non-compliant.
        if size.kind notin {Integer, Float}:
          # i. Perform ! CreateDataPropertyOrThrow(array, "0", len).
          internal.sequence[0] = size

          # ii. Let intLen be 1𝔽.
          intLen = 1'u32
        else:
          # d. Else,
          # i. Let intLen be ! ToUint32(len).
          intLen = uint32(runtime.ToNumber(size))

          if uint32(runtime.ToNumber(size)) != intLen:
            # ii. If SameValueZero(intLen, len) is false, throw a RangeError exception.
            runtime.rangeError("something i think") # TODO: proper message

        # e. Perform ! Set(array, "length", intLen, true).
        arr["length"] = intLen
        for i in 0 ..< intLen:
          internal.sequence &= undefined(runtime)

        # f. Return array.
        ret arr

      # 6. Assert: numberOfArgs ≥ 2.
      assert(numberOfArgs >= 2)

      # 7. Let array be ? ArrayCreate(numberOfArgs, proto).
      let arr = ArrayCreate(runtime, numberOfArgs)
      let internal = &getHiddenField(arr, "internal")

      # 8. Let k be 0.
      var k: uint32

      # 9. Repeat, while k < numberOfArgs,
      while k < numberOfArgs:
        # TODO: Make this compliant.
        # a. Let Pk be ! ToString(𝔽(k)).

        # b. Let itemK be values[k].
        let itemK = &runtime.argument(cast[uint8](k + 1))

        # c. Perform ! CreateDataPropertyOrThrow(array, Pk, itemK).
        internal.sequence[k] = itemK

        # d. Set k to k + 1.
        inc k

      # 10. Assert: The mathematical value of array's "length" property is numberOfArgs.
      # assert(numberOfArgs == )

      # 11. Return array.
      ret arr
    ,
  )

  runtime.definePrototypeFn(
    JSArray,
    "join",
    proc(this: JSValue) =
      # 23.1.3.18 Array.prototype.join ( separator )
      # This method converts the elements of the array to Strings, and then concatenates these Strings, separated by occurrences of the separator. If no separator is provided, a single comma is used as the separator.
      # It performs the following steps when called:

      # 1. Let O be ? ToObject(this value).
      let obj = this # TODO

      # 2. Let len be ? LengthOfArrayLike(O).
      let length = LengthOfArrayLike(runtime, obj)

      # 3. If separator is undefined, let sep be ",".
      let separator = block:
        var res = ","
        if runtime.argumentCount > 0:
          let sep = &runtime.argument(1)

          if not sep.isUndefined:
            # 4. Else, let sep be ? ToString(separator).
            res = runtime.ToString(sep)

        ensureMove(res)

      var
        # 5. Let R be the empty String.
        r: string # TODO: Can we prealloc this

        # 6. Let k be 0.
        k: uint32

      # 7. Repeat, while k < len,
      while k < length:
        # a. If k > 0, set R to the string-concatenation of R and sep.
        if k > 0:
          r &= separator

        # b. Let element be ? Get(O, ! ToString(𝔽(k))).
        let element = runtime.indexArray(obj, k)

        # c. If element is neither undefined nor null, then
        if not element.isUndefined and not element.isNull:
          # i. Let S be ? ToString(element).
          let strElem = runtime.ToString(element)

          # ii. Set R to the string-concatenation of R and S.
          r &= strElem

        # d. Set k to k + 1.
        inc k

      # 8. Return R.
      ret ensureMove(r)
    ,
  )

  runtime.definePrototypeFn(
    JSArray,
    "push",
    proc(this: JSValue) =
      # 23.1.3.23 Array.prototype.push ( ...items )
      # This method performs the following steps when called:

      # 1. Let O be ? ToObject(this value).
      let obj = this # TODO: ToObject

      # 2. Let len be ? LengthOfArrayLike(O).
      var length = cast[uint64](LengthOfArrayLike(runtime, obj))

      # 3. Let argCount be the number of elements in items.
      let argCount = cast[uint64](runtime.argumentCount)

      # 4. If len + argCount > 2**53 - 1, throw a TypeError exception.
      if (length + argCount) > cast[uint64](2 ^ 53 - 1):
        runtime.typeError("Cannot push more items into Array")
        return

      let internal = &getHiddenField(obj, "internal")

      # 5. For each element E of items, do
      for i in 1 .. runtime.argumentCount:
        let elem = &runtime.argument(i, required = true)

        # a. Perform ? Set(O, ! ToString(𝔽(len)), E, true).
        internal.sequence.setLen(length + cast[uint64](i))
        internal.sequence[length] = elem

        # b. Set len to len + 1.
        inc length

      # 6. Perform ? Set(O, "length", 𝔽(len), true).
      obj["length"] = runtime.wrap(length)

      ret ensureMove(length)
    ,
  )

  runtime.definePrototypeFn(
    JSArray,
    "pop",
    proc(this: JSValue) =
      # 23.1.3.22 Array.prototype.pop ( )
      # This method performs the following steps when called:

      # 1. Let O be ? ToObject(this value).
      let obj = this # TODO: ToObject

      # 2. Let len be ? LengthOfArrayLike(O).
      let length = LengthOfArrayLike(runtime, obj)

      # 3. If len = 0, then
      if length == 0:
        # a. Perform ? Set(O, "length", +0𝔽, true).
        obj["length"] = runtime.wrap(0)

        # b. Return undefined.
        ret undefined(runtime)

      # 4. Assert: len > 0.
      assert(length > 0)

      # 5. Let newLen be 𝔽(len - 1).
      let newLen = length - 1

      let internal = getInternalSeq(obj)

      # 6. Let index be ! ToString(newLen).
      # 7. Let element be ? Get(O, index).
      let element = internal.sequence[newLen]

      # 8. Perform ? DeletePropertyOrThrow(O, index).
      # TODO: Not compliant yet.
      internal.sequence.delete(newLen)

      # 9. Perform ? Set(O, "length", newLen, true).
      obj["length"] = runtime.wrap(newLen)

      # 10. Return element.
      ret element
    ,
  )
