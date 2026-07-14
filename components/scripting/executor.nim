## Routines for handling script execution
## 
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[strformat]
import
  components/scripting/types,
  components/dom/tags,
  components/js/grammar/prelude,
  components/js/runtime/prelude,
  components/js/runtime/vm/interpreter/interpreter
import
  components/scripting/dom/[document, element],
  components/scripting/[url, timeouts],
  components/scripting/html/[navigator, window]
import components/aux/pretty

when defined(unix):
  import components/impure/nix

import pkg/[chronicles, shakar]

logScope:
  topics = "scripting/executor"

proc registerWebBindings(elem: tags.HTMLScriptElement) =
  ## Register all the types for web specifications that we support.

  # we have to register ECMA types earlier, as otherwise bindings below would fail as they rely on ECMA primitives existing
  elem.script.rt.registerEcmaTypes()

  document.generateBindings(elem.script.rt)
  let doc = document.generateGlobal(elem.script.rt, elem.script.document)

  element.generateBindings(elem.script.rt)

  timeouts.generateBindings(elem.script.rt)

  navigator.generateBindings(elem.script.rt)
  navigator.generateGlobal(elem.script.rt)

  window.generateBindings(elem.script.rt)
  window.generateGlobal(elem.script.rt, doc)

  url.generateBindings(elem.script.rt)

proc setupRandomState(rng: out uint64) =
  when defined(unix):
    # NOTE: Is this available on OSX?

    # We're basically just going to mix the two u64s we can derive from
    # the auxiliary vector. We're going to use both of them because why not? :^)
    let
      rand = cast[ptr UncheckedArray[uint64]](nix.getauxval(nix.AT_RANDOM))
      v1 = rand[0]
      v2 = rand[1]

    rng = v1 xor v2
  else:
    # TODO: Implement this for Windows and stuff. For now, we'll let the state be zero.
    rng = 0'u64

proc executeScript*(element: tags.HTMLScriptElement, codeBuffer: string) =
  echo codeBuffer
  let parser = newParser(codeBuffer)
  element.script.ast = parser.parse()
  if element.script.rt == nil:
    element.script.rt = newRuntime(
      file = "<inline-script>" # TODO: We can probably use more descriptive names?
    )

  setupRandomState(element.script.rt.rng)
  element.script.rt.ast = element.script.ast
  element.script.rt.opts = InterpreterOpts(
    test262: false,
    repl: false,
    dumpBytecode: true,
    insertDebugHooks: true,
    codegen: CodegenOpts(
      elideLoops: false,
      loopAllocationEliminator: false,
      aggressivelyFreeRetvals: false,
      deadCodeElimination: false,
      jitCompiler: false,
    ),
    jit: JITOpts(),
  )
  element.script.rt.deathCallback = proc(vm: Interpreter) =
    error "Script execution error"
    debugEcho &"{element.script.rt.ir.name} on {element.script.baseURL}"
    debugEcho &"  pc: {vm.currIndex}; jit: {vm.runningCompiled}; vcount: {vm.stack.len}; exccount: {vm.errors.len}"
    debugEcho &"  halt: {vm.halt}; trace: 0x{cast[uint64](vm.trace):X}"

    debugEcho "  registers:"
    if *vm.registers.retVal:
      debugEcho &" > retval: 0x{cast[uint64](&vm.registers.retval):X}"

    if *vm.registers.error:
      debugEcho &" > error: 0x{cast[uint64](&vm.registers.error):X}"

    stdout.write &" > callargs: ["
    for arg in vm.registers.callArgs:
      stdout.write &"\n    0x{cast[uint64](arg):X} ({(if arg != nil: $arg.kind else: \"\")})  \n"
    debugEcho "]"

  registerWebBindings(element)
  element.script.rt.run()
