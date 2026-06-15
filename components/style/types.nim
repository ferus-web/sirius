## Types for the styling subsystem
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[tables, options]
import components/dom/dom

type
  SelectorKind* = enum
    skType
    skId
    skAttr
    skClass
    skUniversal # skPseudoClass, skPseudoElem

  SelectorList* = seq[ComplexSelector]

  Selector* = object
    case kind*: SelectorKind
    of skType:
      tag*: string
    of skId:
      id*: string
    of skClass:
      class*: string
    of skAttr:
      attr*: string
    of skUniversal: discard

  Combinator* {.pure, size: sizeof(uint8).} = enum
    Descendant
    Child
    Adjacent
    Sibling

  CompoundSelector* = seq[Selector]

  ComplexItem* = object
    selector*: CompoundSelector
    combinator*: Combinator

  ComplexSelector* = seq[ComplexItem]

  CSSUnit* {.pure.} = enum
    Px
    Cm
    Mm
    In
    Percent # TODO: Rem
    Em

  CSSDimension* = object
    value*: float32
    unit*: CSSUnit

  CSSFunction* = object
    name*: string
    arguments*: seq[CSSValue]

  CSSValueKind* {.pure, size: sizeof(uint8).} = enum
    Function
    Integer
    Float
    String
    Dimension
    Hex
    List

  CSSValue* = object
    case kind*: CSSValueKind
    of CSSValueKind.Function:
      fn*: CSSFunction
    of CSSValueKind.Integer:
      num*: int32
    of CSSValueKind.Float:
      flt*: float32
    of CSSValueKind.String:
      str*: string
    of CSSValueKind.Hex:
      hex*: string
    of CSSValueKind.Dimension:
      dim*: CSSDimension
    of CSSValueKind.List:
      list*: seq[CSSValue]

  Declaration* = object
    key*: string
    value*: CSSValue

  Stylesheet* = seq[Rule]
  Rule* = object
    selectors*: SelectorList
    declarations*: seq[Declaration]

  ComputedStyle* = Table[string, CSSValue]
  StyleMap* = Table[Node, ComputedStyle]

func function*(name: string, arguments: seq[CSSValue]): CSSValue {.inline.} =
  CSSValue(
    kind: CSSValueKind.Function, fn: CSSFunction(name: name, arguments: arguments)
  )

func number*(num: int32): CSSValue {.inline.} =
  CSSValue(kind: CSSValueKind.Integer, num: num)

func decimal*(dec: float32): CSSValue {.inline.} =
  CSSValue(kind: CSSValueKind.Float, flt: dec)

func hex*(value: string): CSSValue {.inline.} =
  CSSValue(kind: CSSValueKind.Hex, hex: value)

func dimension*(value: float32, unit: CSSUnit): CSSValue {.inline.} =
  CSSValue(kind: CSSValueKind.Dimension, dim: CSSDimension(value: value, unit: unit))

func parseUnit*(str: string): Option[CSSUnit] =
  case str
  of "px":
    some(CSSUnit.Px)
  of "mm":
    some(CSSUnit.Mm)
  of "cm":
    some(CSSUnit.Cm)
  of "in":
    some(CSSUnit.In)
  of "em":
    some(CSSUnit.Em)
  else:
    none(CSSUnit)

func str*(str: string): CSSValue {.inline.} =
  CSSValue(kind: CSSValueKind.String, str: str)

func universalSelector*(): Selector {.inline.} =
  Selector(kind: skUniversal)

func typeSelector*(tag: string): Selector {.inline.} =
  Selector(kind: skType, tag: tag)

func idSelector*(id: string): Selector {.inline.} =
  Selector(kind: skId, id: id)

func classSelector*(class: string): Selector {.inline.} =
  Selector(kind: skClass, class: class)
