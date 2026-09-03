## Niskriya is Sirius' WebIDL to Nim generator
## Usage: niskriya [path to file] [output file]
import std/[os, sequtils, strutils, strformat, deques]
import components/idl/codegen, components/aux/pretty
import ./argparser
import pkg/[webidl2nim, jsony]

proc showHelp() =
  echo """
Niskriya is Ferus/Sirius' WebIDL to Nim code generator.

Usage: niskriya [path to IDL file] [output destination]

Flags:
  --dump-tree, -D             Dump the WebIDL source tree
"""
  quit(0)

proc patchSource*(src: string): string =
  ## "Patch" the IDL source to remove [Exposed] attributes since the parser explodes upon seeing them.
  var lines = src.splitLines()

  for line in lines:
    if line.startsWith("[Expose"):
      continue

    result &= line & '\n'

proc main() =
  var input = parseInput()
  if input.enabled("help", "h"):
    showHelp()

  if input.arguments.len < 1:
    quit("niskriya: expected atleast 2 arguments, got none.")

  let
    source = input.command
    destination = input.arguments[0]

  if not fileExists(source):
    quit("niskriya: no such file exists: {source}")

  let content =
    try:
      readFile(source)
    except OSError as exc:
      quit(&"niskriya: whilst reading source file: {exc.msg}")

  let tokens = tokenize(patchSource(content))

  let tree = parseCode(tokens).stack.toSeq()
  if input.enabled("dump-tree", "D"):
    print(tree)
    quit(0)

  echo "niskriya: generating Bali wrapper"
  let wrapper = generateWrapper(tree)

  try:
    writeFile(destination, wrapper & '\n')
  except OSError as exc:
    echo "niskriya: failed to write to destination: " & exc.msg

when isMainModule:
  main()
