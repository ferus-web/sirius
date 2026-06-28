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
import components/scripting/dom/[document, element], components/scripting/timeouts
import pkg/[chronicles, shakar, url]

logScope:
  topics = "scripting/executor"

proc registerWebBindings(elem: tags.HTMLScriptElement) =
  ## Register all the types for web specifications that we support.

  # we have to register ECMA types earlier, as otherwise bindings below would fail as they rely on ECMA primitives existing
  elem.script.rt.registerEcmaTypes()

  document.generateBindings(elem.script.rt)
  document.generateGlobal(elem.script.rt, elem.script.document)

  element.generateBindings(elem.script.rt)

  timeouts.generateBindings(elem.script.rt)

proc executeScript*(element: tags.HTMLScriptElement, codeBuffer: string) =
  let parser = newParser(codeBuffer)
  element.script.ast = parser.parse()
  if element.script.rt == nil:
    element.script.rt = newRuntime(
      file = "<inline-script>" # TODO: We can probably use more descriptive names?
    )

  element.script.rt.ast = element.script.ast
  element.script.rt.opts = InterpreterOpts(
    test262: false,
    repl: false,
    dumpBytecode: false,
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
  element.script.rt.deathCallback = proc(vm: PulsarInterpreter) =
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
