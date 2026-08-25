## DOM types
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, hashes, tables]
import components/net/cookie, components/js/runtime/prelude as js
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

  EventDispatchEffect = object

  EventListener* = object
    rt*: js.Runtime
    callback*: js.JSValue
    setter*: bool ## was this set via one of the `on*` setters?

  Node* = ref object of RootObj
    childList*: seq[Node]
    parentNode* {.cursor.}: Node

    listeners*: Table[string, seq[EventListener]]

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

func addEventListener*(node: Node, event: string, listener: EventListener) =
  # specs? never heard of her
  if not node.listeners.contains(event):
    node.listeners[event] = @[listener]
    return

  if listener.setter:
    for i, existingListener in node.listeners[event]:
      if existingListener.setter:
        # If these are both set via those `on*` setters, overwrite the preexisting one, and be done with it.
        node.listeners[event][i] = listener
        return

  # Otherwise, append a new EventListener instead
  node.listeners[event] &= listener

proc dispatchEvent*[T](node: Node, event: string, eventObj: T): bool =
  if not node.listeners.contains(event):
    # JS-land doesn't care about this event for this node.
    return

  for listener in node.listeners[event]:
    # evil rt routing
    listener.rt.callNoRetval(listener.callback, @[listener.rt.wrap(eventObj)])

  # TODO: This should ideally check eventObj's internal prevented-default
  # field, but this'll suffice for now. I want to go to sleep in peace. :^)
  true

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
