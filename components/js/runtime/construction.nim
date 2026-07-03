## Helpers for constructing JSValue(s) without breaking your fingers
## 
## Copyright (C) 2025 Trayambak Rai (xtrayambak at disroot dot org)

#!fmt: off
import components/js/runtime/vm/atom,
       components/js/runtime/types
#!fmt: on

{.push inline, sideEffect.}

proc integer*(runtime: Runtime, value: SomeInteger): JSValue =
  integer(runtime.realm.heap, value)

proc floating*(runtime: Runtime, value: SomeFloat | SomeInteger): JSValue =
  floating(runtime.realm.heap, value)

proc str*(runtime: Runtime, value: string): JSValue =
  str(runtime.realm.heap, value)

proc sequence*(runtime: Runtime, value: seq[MAtom]): JSValue =
  sequence(runtime.realm.heap, value)

proc undefined*(runtime: Runtime): JSValue =
  undefined(runtime.realm.heap)

proc null*(runtime: Runtime): JSValue =
  null(runtime.realm.heap)

proc bigint*(runtime: Runtime, value: SomeInteger | string): JSValue =
  bigint(runtime.realm.heap, value)

proc boolean*(runtime: Runtime, value: bool): JSValue =
  boolean(runtime.realm.heap, value)

proc obj*(runtime: Runtime): JSValue =
  obj(runtime.realm.heap)

{.pop.}
