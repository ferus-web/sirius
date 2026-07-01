## Ferrite's `UTF16View`, with most of the useless, unsafe and ridiculously bad bits stripped away.
##
## Copyright (C) 2025-2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, unicode]
import components/impure/simdutf
import pkg/[results]

const
  HighSurrogateMin*: uint16 = 0xD800
  HighSurrogateMax*: uint16 = 0xDBFF
  LowSurrogateMin*: uint16 = 0xDC00
  LowSurrogateMax*: uint16 = 0xDFFF
  ReplacementCodePoint*: uint32 = 0xFFFD
  FirstSupplementaryPlaneCodePoint*: uint32 = 0x10000

func isHighSurrogate*(codeUnit: uint16): bool =
  (codeUnit >= HighSurrogateMin) and (codeUnit <= HighSurrogateMax)

func isLowSurrogate*(codeUnit: uint16): bool =
  (codeUnit >= LowSurrogateMin) and (codeUnit <= LowSurrogateMax)

type
  UTFEndianness* {.size: sizeof(uint8), pure.} = enum
    Big
    Little
    Host

  UTF16View* = object
    data: ptr uint16
    size*: uint64

    endianness: UTFEndianness

    cachedCpLength: Option[uint64]

proc `=destroy`*(view: UTF16View) =
  if view.data == nil:
    return

  deallocShared(view.data)

proc newUtf16View*(str: ptr char, size: uint64): UTF16View {.raises: [].} =
  ## Convert a UTF-8 buffer to a `UTF16View`
  var view: UTF16View

  if size > 0:
    view.size = simdutf.utf16LengthFromUtf8(str, size)
    view.data = cast[ptr uint16](allocShared0(cast[uint64](sizeof(uint16)) * view.size))
    discard simdutf.convertUtf8ToUtf16(str, size, view.data)

  ensureMove(view)

proc newUtf16View*(str: sink string): UTF16View =
  newUtf16View(
    if str.len > 0:
      str[0].addr
    else:
      nil,
    cast[uint64](str.len),
  )

func empty*(view: UTF16View): bool {.inline, raises: [].} =
  ## Check whether this view has no data
  view.data == nil or view.size == 0'u64

func codepointLen*(view: UTF16View): uint64 =
  if view.data == nil:
    raise newException(Defect, "UTF16View has no buffer attached")

  case view.endianness
  of UTFEndianness.Little:
    simdutf.countUtf16LE(view.data, view.size)
  of UTFEndianness.Big:
    simdutf.countUtf16BE(view.data, view.size)
  of UTFEndianness.Host:
    simdutf.countUtf16(view.data, view.size)

func codeUnitAt*(
    view: UTF16View, index: SomeUnsignedInt
): uint16 {.inline, raises: [].} =
  ## Get the UTF-16 code unit at `index`
  if view.data == nil:
    raise newException(Defect, "UTF16View has no buffer attached")

  cast[ptr uint16](cast[uint64](view.data) + index)[]
    # TODO: Can we not just use ptr UncheckedArray[uint16] here?

func decodeSurrogatePair*(high, low: uint16): uint32 {.inline, raises: [ValueError].} =
  ## Decode a surrogate pair.
  ## `high` must be a high surrogate, and `low` must be a low surrogate.
  ## Otherwise, a `ValueError` will be raised if either of the conditions are not met.
  if not high.isHighSurrogate:
    raise newException(ValueError, $high & " is not a high surrogate")

  if not low.isLowSurrogate:
    raise newException(ValueError, $low & " is not a low surrogate")

  ((high - HighSurrogateMin).uint32 shl 10'u32) + (low - LowSurrogateMin).uint32 +
    FirstSupplementaryPlaneCodePoint

func codePointAt*(
    view: UTF16View, index: SomeUnsignedInt
): uint32 {.raises: [ValueError].} =
  ## Get the code point at `index` in this view.
  if view.data == nil:
    raise newException(Defect, "UTF16View has no buffer attached")

  if index > view.size:
    raise newException(IndexDefect, "Index " & $index & " is out of range")

  let codePoint = view.codeUnitAt(index)
  if not isHighSurrogate(codePoint) and not isLowSurrogate(codePoint):
    return uint32(cast[uint16](codePoint))

  if isLowSurrogate(codePoint) or (index + 1 == view.size):
    return uint32(cast[uint16](codePoint))

  let second = view.codeUnitAt(index + 1)
  if not isLowSurrogate(second):
    return uint32(cast[uint16](codePoint))

func `==`*(a, b: UTF16View): bool {.inline, raises: [].} =
  ## Compare two views together
  a.endianness == b.endianness and a.size == b.size and
    ((a.empty and b.empty) or cmpMem(a.data, b.data, a.size) == 0)

func start*(view: UTF16View): uint16 {.inline.} =
  ## Get the initial codepoint for this view.
  if view.data == nil:
    raise newException(Defect, "UTF16View has no buffer attached")

  view.data[]

func valid*(view: UTF16View): bool {.inline, raises: [].} =
  if view.data == nil:
    return false # TODO: Should this be a defect too, instead?

  case view.endianness
  of UTFEndianness.Little:
    simdutf.validateUtf16LE(view.data, view.size)
  of UTFEndianness.Big:
    simdutf.validateUtf16BE(view.data, view.size)
  of UTFEndianness.Host:
    simdutf.validateUtf16(view.data, view.size)

proc isomorphicDecode*(input: string): Option[UTF16View] {.inline.} =
  ## To isomorphic decode a byte sequence input, return a string whose code point length is equal to input’s length and whose code points have the same values as the values of input’s bytes, in the same order. 
  if input.len > 0:
    let view = UTF16View(
      data: cast[ptr uint16](allocShared0(input.len)), size: cast[uint64](input.len)
    )
    copyMem(cast[pointer](view.data), cast[pointer](input[0].addr), input.len)

    return some(view)

  none(UTF16View)
