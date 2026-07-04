## Routines to serialize the DOM into its string representation.
## Some parts of the logic here were taken from Chawan.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import components/dom/[dom, tags]

type EscapeMode* {.pure, size: sizeof(uint8).} = enum
  All
  Attribute
  Text

func htmlEscape*(data: openArray[char], mode: EscapeMode = EscapeMode.All): string =
  var
    buffer = newStringOfCap(data.len) # best case: we need to do nothing
    nbspMode: bool

  for c in data:
    if nbspMode:
      if c == '\xA0':
        buffer &= "&nbsp;"
      else:
        buffer &= '\xC2' & c

      nbspMode = false
      continue

    case c
    of '<':
      buffer &= "&lt;"
    of '>':
      buffer &= "&gt;"
    of '&':
      buffer &= "&amp;"
    of '\xC2':
      nbspMode = true
    of '"':
      if mode <= EscapeMode.Attribute:
        buffer &= "&quot;"
    of '\'':
      if mode == EscapeMode.All:
        buffer &= "&apos;"
    else:
      buffer &= c

  ensureMove(buffer)

func serializeFragment*(res: var string, node: dom.Node, writeShadow: bool = false)

func serializeFragmentInner(
    res: var string, child: Node, parentType: TagType, writeShadow: bool
) =
  if child of Element:
    let element = Element(child)
    let tags = element.document.factory.atomToStr(element.localName)
    res &= '<'
    #TODO qualified name if not HTML, SVG or MathML
    res &= tags
    #TODO custom elements
    for attr in element.attrs:
      res &=
        ' ' & atomToStr(element.document.factory, attr.name) & "=\"" &
        attr.value.htmlEscape(mode = EscapeMode.Attribute) & "\""
    res &= '>'
    res.serializeFragment(element, writeShadow)
    res &= "</" & tags & '>'
  elif child of Text:
    let text = Text(child)
    const LiteralTags = {
      TAG_STYLE, TAG_SCRIPT, TAG_XMP, TAG_IFRAME, TAG_NOEMBED, TAG_NOFRAMES,
      TAG_PLAINTEXT, TAG_NOSCRIPT,
    }
    if parentType in LiteralTags:
      res &= text.data
    else:
      res &= text.data.htmlEscape(mode = EscapeMode.Text)
  elif child of Comment:
    res &= "<!--" & Comment(child).data & "-->"
  elif child of DocumentType:
    res &= "<!DOCTYPE " & DocumentType(child).name & '>'

func serializeFragment*(res: var string, node: dom.Node, writeShadow: bool = false) =
  var node = node
  var parentType = TAG_UNKNOWN

  if node of dom.Element:
    let element = Element(node)
    const VoidElements = {
      TAG_AREA, TAG_BASE, TAG_BR, TAG_COL, TAG_EMBED, TAG_HR, TAG_IMG, TAG_INPUT,
      TAG_LINK, TAG_META, TAG_SOURCE, TAG_TRACK, TAG_WBR,
    }
    const Extra = {TAG_BASEFONT, TAG_BGSOUND, TAG_FRAME, TAG_KEYGEN, TAG_PARAM}
    if element.tagType in VoidElements + Extra:
      return
    if element of HTMLTemplateElement:
      node = HTMLTemplateElement(element).content
    else:
      parentType = element.tagType
      if parentType == TAG_NOSCRIPT:
        # Pretend parentType is not noscript, so we do not append literally
        # in serializeFragmentInner.
        parentType = TAG_UNKNOWN
      #[ let shadow = element.shadowRoot
      if shadow != nil and writeShadow and shadow.serializable:
        res &= "<template shadowrootmode=\"" & $shadow.mode & '"'
        if shadow.delegatesFocus:
          res &= " shadowrootdelegatesfocus=\"\""
        if shadow.serializable:
          res &= " shadowrootserializable=\"\""
        if shadow.clonable:
          res &= " shadowrootclonable=\"\""
        let docCustomElements = node.document.customElements
        let shadowCustomElements = shadow.customElements
        if docCustomElements != nil and not docCustomElements.scoped or
            shadowCustomElements != nil and not shadowCustomElements.scoped:
          res &= " shadowrootcustomelementregistry=\"\""
        res &= '>'
        res.serializeFragment(shadow, writeShadow)
        res &= "</template>" ]#

  for child in node.childList:
    res.serializeFragmentInner(child, parentType, writeShadow)

func serializeFragment*(node: dom.Node): string =
  var buffer: string
  serializeFragment(buffer, node)

  ensureMove(buffer)
