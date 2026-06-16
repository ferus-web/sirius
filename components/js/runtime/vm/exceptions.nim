import std/[options, strutils]
import components/js/runtime/vm/atom

type
  ExceptionTrace* = ref object
    prev*, next*: Option[ExceptionTrace]
    clause*: int
    index*: uint
    exception*: RuntimeException

  RuntimeException* = ref object of RootObj
    operation*: uint
    clause*: string
    message*: string

  WrongType* = ref object of RuntimeException

proc clone*(exc: RuntimeException): RuntimeException =
  if exc == nil:
    return nil

  RuntimeException(operation: exc.operation, clause: exc.clause, message: exc.message)

proc wrongType*(expected, got: MAtomKind): WrongType {.inline, noSideEffect, gcsafe.} =
  WrongType(message: "Expected $1; got $2 instead." % [$expected, $got])
