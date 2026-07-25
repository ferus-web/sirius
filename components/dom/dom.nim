## DOM types
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, hashes]
import components/net/cookie
import pkg/chame/[htmlparser, tags], pkg/url

export tags

# Atom implementation
# TODO maybe we should use a better hash map.
const AtomFactoryStrMapLength = 1024 # must be a power of 2
static:
  doAssert (AtomFactoryStrMapLength and (AtomFactoryStrMapLength - 1)) == 0

type
  Atom* = distinct int

  AtomFactory* = ref object of RootObj
    strMap: array[AtomFactoryStrMapLength, seq[Atom]]
    atomMap: seq[string]

func toTagType*(atom: Atom): TagType {.inline.} =
  if int(atom) <= int(high(TagType)):
    return TagType(atom)
  return TAG_UNKNOWN

func cmp*(a, b: Atom): int {.inline.} =
  return cmp(int(a), int(b))

type
  Attribute* = ParsedAttr[Atom]

  Node* = ref object of RootObj
    childList*: seq[Node]
    parentNode* {.cursor.}: Node

  CharacterData* = ref object of Node
    data*: string

  Comment* = ref object of CharacterData

  Document* = ref object of Node
    factory*: AtomFactory

    language*: Option[string]

    # sirius-specific stuff
    edited*: bool
    willDeclarativelyRefresh*: bool
    cookies*: seq[Cookie]
    url*: URL

  Text* = ref object of CharacterData

  DocumentType* = ref object of Node
    name*: string
    publicId*: string
    systemId*: string

  Element* = ref object of Node
    localName*: Atom
    namespace*: Namespace
    attrs*: seq[Attribute]
    document*: Document

  DocumentFragment* = ref object of Node

# Mandatory Atom functions
func `==`*(a, b: Atom): bool {.borrow.}
func hash*(atom: Atom): Hash {.borrow.}

func strToAtom*(factory: AtomFactory, s: string): Atom

proc newAtomFactory*(): AtomFactory =
  const minCap = int(TagType.high) + 1
  let factory = AtomFactory(atomMap: newSeqOfCap[string](minCap))
  factory.atomMap.add("") # skip TAG_UNKNOWN
  for tagType in TagType(int(TAG_UNKNOWN) + 1) .. TagType.high:
    discard factory.strToAtom($tagType)
  return factory

func strToAtom*(factory: AtomFactory, s: string): Atom =
  let h = s.hash()
  let i = h and (factory.strMap.len - 1)
  for atom in factory.strMap[i]:
    if factory.atomMap[int(atom)] == s:
      # Found
      return atom
  # Not found
  let atom = Atom(factory.atomMap.len)
  factory.atomMap.add(s)
  factory.strMap[i].add(atom)
  return atom

func tagTypeToAtom*(factory: AtomFactory, tagType: TagType): Atom =
  assert tagType != TAG_UNKNOWN
  return Atom(tagType)

func atomToStr*(factory: AtomFactory, atom: Atom): string =
  return factory.atomMap[int(atom)]

func tagType*(element: Element): TagType =
  return element.localName.toTagType()
