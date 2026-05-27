## Types for the styling subsystem
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[tables, options]
import components/html/dom

type
  SelectorKind* = enum
    skType
    skId
    skAttr
    skClass
    skUniversal # skPseudoClass, skPseudoElem

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

  PseudoClass* = enum
    pcFirstChild
    pcLastChild
    pcOnlyChild
    pcHover
    pcRoot
    pcNthChild
    pcNthLastChild
    pcChecked
    pcFocus
    pcIs
    pcNot
    pcWhere
    pcLang
    pcLink
    pcVisited

  CSSUnit* {.pure.} = enum
    Px
    Cm
    Mm
    In
    Percent # TODO: Rem

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

  Stylesheet* = seq[Rule]
  Rule* = object
    selector*: Selector
    key*: string
    value*: CSSValue

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

func dimension*(value: float32, unit: CSSUnit): CSSValue {.inline.} =
  CSSValue(kind: CSSValueKind.Dimension, dim: CSSDimension(value: value, unit: unit))

func parseUnit*(str: string): Option[CSSUnit] =
  case str
  of "px":
    return some(CSSUnit.Px)
  of "mm":
    return some(CSSUnit.Mm)
  of "cm":
    return some(CSSUnit.Cm)
  of "in":
    return some(CSSUnit.In)
  else:
    discard

func str*(str: string): CSSValue {.inline.} =
  CSSValue(kind: CSSValueKind.String, str: str)

func universalSelector*(): Selector {.inline.} =
  Selector(kind: skUniversal)

func tagSelector*(tag: string): Selector {.inline.} =
  Selector(kind: skType, tag: tag)
