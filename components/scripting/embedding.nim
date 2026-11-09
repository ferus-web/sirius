## JavaScript-land routines for the Embedding API
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/js/runtime/prelude, components/js/runtime/abstract/[to_number]
import pkg/shakar
import components/aux/pretty, tables

type
  EmbeddingHostCallbacks* = object
    fire*: proc(rt: Runtime, meth: string, arguments: seq[JSValue]) {.gcsafe.}

  EmbeddingOpts* = object
    enabled*: bool
    namespace*: string

  EmbedBinding = object

proc generateGlobal*(rt: Runtime, namespace: string, window: JSValue) =
  let bindingsObject = rt.createObjFromType(EmbedBinding)
  window[namespace] = bindingsObject

proc generateBindings*(rt: Runtime, callbacks: EmbeddingHostCallbacks) =
  rt.registerType("EmbedBinding", EmbedBinding)
  rt.definePrototypeFn(
    EmbedBinding,
    "fire",
    proc(this: JSValue) =
      let
        nativeMethod = &rt.argument(1)
        argCount = max(0, rt.argumentCount - 1)

      var args = newSeqOfCap[JSValue](argCount)
      for argc in 2 ..< 2 + argCount:
        args &= &rt.argument(argc)

      callbacks.fire(rt, rt.ToString(nativeMethod), ensureMove(args))

      let runtime = rt # HACK: Again, I wish `ret` could handle this.
      ret undefined(rt)
    ,
  )
