## DOM types
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, hashes]
import pkg/chame/[htmlparser, tags]

export tags

# Atom implementation
# TODO maybe we should use a better hash map.
const MAtomFactoryStrMapLength = 1024 # must be a power of 2
static:
  doAssert (MAtomFactoryStrMapLength and (MAtomFactoryStrMapLength - 1)) == 0

type
  MAtom* = distinct int

  MAtomFactory* = ref object of RootObj
    strMap: array[MAtomFactoryStrMapLength, seq[MAtom]]
    atomMap: seq[string]

func toTagType*(atom: MAtom): TagType {.inline.} =
  if int(atom) <= int(high(TagType)):
    return TagType(atom)
  return TAG_UNKNOWN

func cmp*(a, b: MAtom): int {.inline.} =
  return cmp(int(a), int(b))

type
  Attribute* = ParsedAttr[MAtom]

  Node* = ref object of RootObj
    childList*: seq[Node]
    parentNode* {.cursor.}: Node

  CharacterData* = ref object of Node
    data*: string

  Comment* = ref object of CharacterData

  Document* = ref object of Node
    factory*: MAtomFactory
    edited*: bool

  Text* = ref object of CharacterData

  DocumentType* = ref object of Node
    name*: string
    publicId*: string
    systemId*: string

  Element* = ref object of Node
    localName*: MAtom
    namespace*: Namespace
    attrs*: seq[Attribute]
    document*: Document

  DocumentFragment* = ref object of Node

# Mandatory Atom functions
func `==`*(a, b: MAtom): bool {.borrow.}
func hash*(atom: MAtom): Hash {.borrow.}

func strToAtom*(factory: MAtomFactory, s: string): MAtom

proc newMAtomFactory*(): MAtomFactory =
  const minCap = int(TagType.high) + 1
  let factory = MAtomFactory(atomMap: newSeqOfCap[string](minCap))
  factory.atomMap.add("") # skip TAG_UNKNOWN
  for tagType in TagType(int(TAG_UNKNOWN) + 1) .. TagType.high:
    discard factory.strToAtom($tagType)
  return factory

func strToAtom*(factory: MAtomFactory, s: string): MAtom =
  let h = s.hash()
  let i = h and (factory.strMap.len - 1)
  for atom in factory.strMap[i]:
    if factory.atomMap[int(atom)] == s:
      # Found
      return atom
  # Not found
  let atom = MAtom(factory.atomMap.len)
  factory.atomMap.add(s)
  factory.strMap[i].add(atom)
  return atom

func tagTypeToAtom*(factory: MAtomFactory, tagType: TagType): MAtom =
  assert tagType != TAG_UNKNOWN
  return MAtom(tagType)

func atomToStr*(factory: MAtomFactory, atom: MAtom): string =
  return factory.atomMap[int(atom)]

func tagType*(element: Element): TagType =
  return element.localName.toTagType()
