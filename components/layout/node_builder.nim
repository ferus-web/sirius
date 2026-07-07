## Routines for turning the DOM and computed styles into a layout tree
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[hashes, options, sequtils, strformat, strutils, tables]
import
  components/css/[level1, text, text_decoration, types],
  components/dom/[dom, tags],
  components/html/dom_utils,
  components/style/types,
  components/layout/types,
  components/os/fonts
import pkg/[chronicles, chroma, pixie, results, shakar]

logScope:
  topics = "layout/node_builder"

const
  DisplayAttr = "display"
  FontSizeAttr = "font-size"
  FontFamilyAttr = "font-family"

  MarginBottomAttr = "margin-bottom"
  MarginTopAttr = "margin-top"
  MarginLeftAttr = "margin-left"
  MarginRightAttr = "margin-right"
  MarginAttr = "margin"

  ColorAttr = "color"
  BackgroundColorAttr = "background-color"

  CursorAttr = "cursor"

  LineHeightAttr = "line-height"
  PaddingAttr = "padding"

  TextDecorationAttr = "text-decoration"

  WidthAttr = "width"
  HeightAttr = "height"

  WhitespaceAttr = "white-space"

  FloatAttr = "float"

  BorderAttr = "border"
  BorderWidthAttr = "border-width"
  BorderColorAttr = "border-color"
  BorderStyleAttr = "border-style"

  TextAlignAttr = "text-align"

func cleanFontFamily(family: CSSValue): string =
  ## Clean up the font-family attribute so fontconfig can easily parse it internally.
  # TODO: This routine doesn't belong here.

  case family.kind
  of CSSValueKind.String:
    return family.str
  of CSSValueKind.List:
    return family.list.mapIt(it.str).join(",")
  else:
    discard

proc applyRectAttr[T: object](output: var T, prop: CSSValue): Result[void, string] =
  case prop.kind
  of CSSValueKind.Dimension, CSSValueKind.Integer, CSSValueKind.Float:
    let value = some(prop)
    output.top = value
    output.bottom = value
    output.left = value
    output.right = value
  of CSSValueKind.List:
    case prop.list.len
    of 1:
      unreachable
    of 2:
      let
        horiz = some(prop.list[0])
        vert = some(prop.list[1])

      output.top = vert
      output.bottom = vert
      output.left = horiz
      output.right = horiz
    of 3:
      output.top = some(prop.list[0])
      output.left = some(prop.list[1])
      output.right = some(prop.list[1])
      output.bottom = some(prop.list[2])
    of 4:
      output.top = some(prop.list[0])
      output.right = some(prop.list[1])
      output.bottom = some(prop.list[2])
      output.left = some(prop.list[3])
    else:
      return err(
        &"Property expects four values at most, got {prop.list.len} values instead."
      )
  else:
    return err(
      &"Property expects dimension, numeric or list of dimensions and numerics, got {prop.kind} instead."
    )

  ok()

proc execColoringFunction*(fn: CSSFunction): ColorRGBA =
  var col = rgba(0, 0, 0, 255)

  if fn.name == "rgb":
    # FIXME: this assumes ~perfectly valid inputs
    let
      r = fn.arguments[0]
      g = fn.arguments[1]
      b = fn.arguments[2]

    if r.kind == CSSValueKind.Float:
      col.r = uint8(255'f32 * r.flt)
    elif r.kind == CSSValueKind.Integer:
      col.r = uint8(r.num)

    if g.kind == CSSValueKind.Float:
      col.g = uint8(255'f32 * g.flt)
    elif b.kind == CSSValueKind.Integer:
      col.g = uint8(g.num)

    if b.kind == CSSValueKind.Float:
      col.b = uint8(255'f32 * b.flt)
    elif b.kind == CSSValueKind.Integer:
      col.b = uint8(b.num)

    col.a = 255'u8
  else:
    warn "Unhandled function", name = fn.name

  ensureMove(col)

proc handleNamedColor(value: string): Option[ColorRGBA] =
  # https://www.w3.org/TR/css-color-3/#svg-color
  let colorMap {.global.} = toTable {
    "aliceblue": rgb(240, 248, 255),
    "antiquewhite": rgb(250, 235, 215),
    "aqua": rgb(0, 255, 255),
    "aquamarine": rgb(127, 255, 212),
    "azure": rgb(240, 255, 255),
    "beige": rgb(245, 245, 220),
    "bisque": rgb(255, 228, 196),
    "black": rgb(0, 0, 0),
    "blanchedalmond": rgb(255, 235, 205),
    "blue": rgb(0, 0, 255),
    "blueviolet": rgb(138, 43, 226),
    "brown": rgb(165, 42, 42),
    "burlywood": rgb(222, 184, 135),
    "cadetblue": rgb(95, 158, 160),
    "chartreuse": rgb(127, 255, 0),
    "chocolate": rgb(210, 105, 30),
    "coral": rgb(255, 127, 80),
    "cornflowerblue": rgb(100, 149, 237),
    "cornsilk": rgb(255, 248, 220),
    "crimson": rgb(220, 20, 60),
    "cyan": rgb(0, 255, 255),
    "darkblue": rgb(0, 0, 139),
    "darkcyan": rgb(0, 139, 139),
    "darkgoldenrod": rgb(184, 134, 11),
    "darkgray": rgb(169, 169, 169),
    "darkgreen": rgb(0, 100, 0),
    "darkgrey": rgb(169, 169, 169),
    "darkkhaki": rgb(189, 183, 107),
    "darkmagenta": rgb(139, 0, 139),
    "darkolivegreen": rgb(85, 107, 47),
    "darkorange": rgb(255, 140, 0),
    "darkorchid": rgb(153, 50, 204),
    "darkred": rgb(139, 0, 0),
    "darksalmon": rgb(233, 150, 122),
    "darkseagreen": rgb(143, 188, 143),
    "darkslateblue": rgb(72, 61, 139),
    "darkslategray": rgb(47, 79, 79),
    "darkslategrey": rgb(47, 79, 79),
    "darkturquoise": rgb(0, 206, 209),
    "darkviolet": rgb(148, 0, 211),
    "deeppink": rgb(255, 20, 147),
    "deepskyblue": rgb(0, 191, 255),
    "dimgray": rgb(105, 105, 105),
    "dimgrey": rgb(105, 105, 105),
    "dodgerblue": rgb(30, 144, 255),
    "firebrick": rgb(178, 34, 34),
    "floralwhite": rgb(255, 250, 240),
    "forestgreen": rgb(34, 139, 34),
    "fuchsia": rgb(255, 0, 255),
    "gainsboro": rgb(220, 220, 220),
    "ghostwhite": rgb(248, 248, 255),
    "gold": rgb(255, 215, 0),
    "goldenrod": rgb(218, 165, 32),
    "gray": rgb(128, 128, 128),
    "green": rgb(0, 128, 0),
    "greenyellow": rgb(173, 255, 47),
    "grey": rgb(128, 128, 128),
    "honeydew": rgb(240, 255, 240),
    "hotpink": rgb(255, 105, 180),
    "indianred": rgb(205, 92, 92),
    "indigo": rgb(75, 0, 130),
    "ivory": rgb(255, 255, 240),
    "khaki": rgb(240, 230, 140),
    "lavender": rgb(230, 230, 250),
    "lavenderblush": rgb(255, 240, 245),
    "lawngreen": rgb(124, 252, 0),
    "lemonchiffon": rgb(255, 250, 205),
    "lightblue": rgb(173, 216, 230),
    "lightcoral": rgb(240, 128, 128),
    "lightcyan": rgb(224, 255, 255),
    "lightgoldenrodyellow": rgb(250, 250, 210),
    "lightgray": rgb(211, 211, 211),
    "lightgreen": rgb(144, 238, 144),
    "lightgrey": rgb(211, 211, 211),
    "lightpink": rgb(255, 182, 193),
    "lightsalmon": rgb(255, 160, 122),
    "lightseagreen": rgb(32, 178, 170),
    "lightskyblue": rgb(135, 206, 250),
    "lightslategray": rgb(119, 136, 153),
    "lightslategrey": rgb(119, 136, 153),
    "lightsteelblue": rgb(176, 196, 222),
    "lightyellow": rgb(255, 255, 224),
    "lime": rgb(0, 255, 0),
    "limegreen": rgb(50, 205, 50),
    "linen": rgb(250, 240, 230),
    "magenta": rgb(255, 0, 255),
    "maroon": rgb(128, 0, 0),
    "mediumaquamarine": rgb(102, 205, 170),
    "mediumblue": rgb(0, 0, 205),
    "mediumorchid": rgb(186, 85, 211),
    "mediumpurple": rgb(147, 112, 219),
    "mediumseagreen": rgb(60, 179, 113),
    "mediumslateblue": rgb(123, 104, 238),
    "mediumspringgreen": rgb(0, 250, 154),
    "mediumturquoise": rgb(72, 209, 204),
    "mediumvioletred": rgb(199, 21, 133),
    "midnightblue": rgb(25, 25, 112),
    "mintcream": rgb(245, 255, 250),
    "mistyrose": rgb(255, 228, 225),
    "moccasin": rgb(255, 228, 181),
    "navajowhite": rgb(255, 222, 173),
    "navy": rgb(0, 0, 128),
    "oldlace": rgb(253, 245, 230),
    "olive": rgb(128, 128, 0),
    "olivedrab": rgb(107, 142, 35),
    "orange": rgb(255, 165, 0),
    "orangered": rgb(255, 69, 0),
    "orchid": rgb(218, 112, 214),
    "palegoldenrod": rgb(238, 232, 170),
    "palegreen": rgb(152, 251, 152),
    "paleturquoise": rgb(175, 238, 238),
    "palevioletred": rgb(219, 112, 147),
    "papayawhip": rgb(255, 239, 213),
    "peachpuff": rgb(255, 218, 185),
    "peru": rgb(205, 133, 63),
    "pink": rgb(255, 192, 203),
    "plum": rgb(221, 160, 221),
    "powderblue": rgb(176, 224, 230),
    "purple": rgb(128, 0, 128),
    "red": rgb(255, 0, 0),
    "rosybrown": rgb(188, 143, 143),
    "royalblue": rgb(65, 105, 225),
    "saddlebrown": rgb(139, 69, 19),
    "salmon": rgb(250, 128, 114),
    "sandybrown": rgb(244, 164, 96),
    "seagreen": rgb(46, 139, 87),
    "seashell": rgb(255, 245, 238),
    "sienna": rgb(160, 82, 45),
    "silver": rgb(192, 192, 192),
    "skyblue": rgb(135, 206, 235),
    "slateblue": rgb(106, 90, 205),
    "slategray": rgb(112, 128, 144),
    "slategrey": rgb(112, 128, 144),
    "snow": rgb(255, 250, 250),
    "springgreen": rgb(0, 255, 127),
    "steelblue": rgb(70, 130, 180),
    "tan": rgb(210, 180, 140),
    "teal": rgb(0, 128, 128),
    "thistle": rgb(216, 191, 216),
    "tomato": rgb(255, 99, 71),
    "turquoise": rgb(64, 224, 208),
    "violet": rgb(238, 130, 238),
    "wheat": rgb(245, 222, 179),
    "white": rgb(255, 255, 255),
    "whitesmoke": rgb(245, 245, 245),
    "yellow": rgb(255, 255, 0),
    "yellowgreen": rgb(154, 205, 50),
  }
  let lowered = toLowerAscii(value)

  if lowered in colorMap:
    let col = colorMap[lowered]
    return some(rgba(col.r, col.g, col.b, 255))

  none(ColorRGBA)

proc parseHexColor(value: string): Option[ColorRGBA] =
  case value.len
  of 3:
    try:
      return some(rgba(parseHtmlHexTiny('#' & value)))
        # FIXME: Just write a routine for this here. This allocation sucks.
    except chroma.InvalidColor as exc:
      return none(ColorRGBA)
  of 6:
    try:
      return some(rgba(parseHex(value)))
    except chroma.InvalidColor:
      return none(ColorRGBA)
  of 8:
    try:
      return some(rgba(parseHexAlpha(value)))
    except chroma.InvalidColor:
      return none(ColorRGBA)
  else:
    return none(ColorRGBA)

proc evaluateColor*(value: CSSValue): Option[ColorRGBA] =
  if value.kind == CSSValueKind.String and
      (let namedColor = handleNamedColor(value.str); *namedColor):
    return namedColor

  if value.kind == CSSValueKind.Function:
    return some(execColoringFunction(value.fn))

  if value.kind == CSSValueKind.Hex and
      (let hexColor = parseHexColor(value.hex); *hexColor):
    return hexColor

  none(ColorRGBA)

proc applyTextDecorationAttr(
    decor: out TextDecoration, value: CSSValue
): Result[void, string] =
  func handleDecorationUnit(
      decor: var TextDecoration, unit: string
  ): Result[void, string] {.inline.} =
    let prop = toLowerAscii(unit)
    if (let decorLine = getTextDecorationLine(prop); *decorLine):
      decor.line = &decorLine
      return ok()

    if (let decorStyle = getTextDecorationStyle(prop); *decorStyle):
      decor.style = &decorStyle
      return ok()

    if (let underlineStyle = getTextUnderlineStyle(prop); *underlineStyle):
      decor.underlineStyle = &underlineStyle
      return ok()

    err(&"Unknown value '{unit}' for text-decoration")

  decor = TextDecoration()
  case value.kind
  of CSSValueKind.String:
    return handleDecorationUnit(decor, value.str)
  of CSSValueKind.List:
    for val in value.list:
      if val.kind != CSSValueKind.String:
        return err(&"Expected String for text-decoration, got {val.kind}")

      let res = handleDecorationUnit(decor, val.str)
      if !res:
        return res
  else:
    return err(
      &"Property 'text-decoration' expects list of decorations or String, got {value.kind} instead."
    )

proc applyBorderAttr(
    border: out Border, prop: static string, value: CSSValue
): Result[void, string] =
  border = Border()

  case value.kind
  of CSSValueKind.Integer, CSSValueKind.Float:
    border.width = some(value)
  of CSSValueKind.Hex:
    border.color = parseHexColor(value.hex)
  of CSSValueKind.List:
    for val in value.list:
      case val.kind
      of CSSValueKind.Float, CSSValueKind.Integer, CSSValueKind.Dimension:
        border.width = some(val)
      of CSSValueKind.String:
        if (let style = getBorderStyle(toLowerAscii(val.str)); *style):
          border.style = style

        if (let color = handleNamedColor(val.str); *color):
          border.color = color
      of CSSValueKind.Function:
        border.color = some(execColoringFunction(val.fn))
      of CSSValueKind.Hex:
        border.color = parseHexColor(val.hex)
      else:
        return err(
          &"Property '{prop}' list expects numeric, function or string, got {val.kind} instead"
        )
  else:
    return err(&"Property '{prop}' expects list or numeric, got {value.kind} instead")

  ok()

proc setStyleProperties(layoutNode: LayoutNode, fontProvider: FontProvider) =
  for attr, prop in layoutNode.style:
    if attr == DisplayAttr:
      if layoutNode.display != DisplayMode.Anonymous:
        if prop.kind != CSSValueKind.String:
          warn "Ignoring display property, expected String.", got = prop.kind
        else:
          layoutNode.display = (
            if prop.str == "block":
              DisplayMode.Block
            elif prop.str == "inline":
              DisplayMode.Inline
            else:
              warn "Unhandled display property for node", display = prop
              DisplayMode.Block
          )
    elif attr == FontSizeAttr:
      layoutNode.fontSize = some(prop)
    elif attr == MarginBottomAttr:
      layoutNode.margins.bottom = some(prop)
    elif attr == "--sirius-noop":
      continue
    elif attr == FontFamilyAttr:
      layoutNode.fontFamily = &fontProvider.getFontByFamily(cleanFontFamily(prop))
        # TODO: Handle fallbacks
    elif attr == MarginTopAttr:
      layoutNode.margins.top = some(prop)
    elif attr == MarginLeftAttr:
      layoutNode.margins.left = some(prop)
    elif attr == MarginRightAttr:
      layoutNode.margins.right = some(prop)
    elif attr == MarginAttr:
      if (let warning = applyRectAttr(layoutNode.margins, prop); !warning):
        warn "Styling warning while applying margin", msg = warning.error()
    elif attr == ColorAttr:
      if (let color = evaluateColor(prop); *color):
        layoutNode.color = &color
    elif attr == BackgroundColorAttr:
      if (let color = evaluateColor(prop); *color):
        layoutNode.backgroundColor = &color
    elif attr == CursorAttr:
      if prop.kind == CSSValueKind.String and prop.str != "auto":
        layoutNode.cursor = some(prop.str)
    elif attr == LineHeightAttr:
      layoutNode.lineHeight = some(prop)
    elif attr == PaddingAttr:
      if (let warning = applyRectAttr(layoutNode.padding, prop); !warning):
        warn "Styling warning while applying padding", msg = warning.error()
    elif attr == TextDecorationAttr:
      if (
        let warning = applyTextDecorationAttr(layoutNode.textDecoration, prop)
        !warning
      ):
        warn "Styling warning while applying text-decoration", msg = warning.error()
    elif attr == WidthAttr:
      layoutNode.width = some(prop)
    elif attr == HeightAttr:
      layoutNode.height = some(prop)
    elif attr == WhitespaceAttr:
      if prop.kind == CSSValueKind.String and (
        let whitespaceProp = getWhitespaceProperty(toLowerAscii(prop.str))
        *whitespaceProp
      ):
        layoutNode.whitespace = &whitespaceProp
    elif attr == FloatAttr:
      if prop.kind == CSSValueKind.String and
          (let floatProp = getFloatMode(toLowerAscii(prop.str)); *floatProp):
        layoutNode.floatMode = &floatProp
    elif attr == BorderAttr:
      if (let warning = applyBorderAttr(layoutNode.border, BorderAttr, prop); !warning):
        warn "Styling warning", msg = warning.error()
    elif attr == BorderColorAttr:
      layoutNode.border.color = evaluateColor(prop)
    elif attr == BorderStyleAttr:
      if prop.kind == CSSValueKind.String:
        layoutNode.border.style = getBorderStyle(prop.str)
    elif attr == BorderWidthAttr:
      case prop.kind
      of CSSValueKind.Float, CSSValueKind.Integer:
        layoutNode.border.width = some(prop)
      else:
        discard
    elif attr == TextAlignAttr:
      if prop.kind == CSSValueKind.String and
          (let alignment = getTextAlignmentProperty(prop.str); *alignment):
        layoutNode.textAlignment = &alignment
    else:
      discard # warn "Unhandled style property", name = attr

proc createLayoutNode*(
    node: dom.Node,
    style: StyleMap,
    fontProvider: FontProvider,
    imageCache: TableRef[string, pixie.Image],
): LayoutNode =
  let layoutNode = LayoutNode(domNode: node)

  if not (node of tags.HTMLInputElement) and node of dom.Text:
    let textData = Text(node).data
    if textData.len < 1 or isEmptyOrWhitespace(textData):
      return

    layoutNode.content = textData
    layoutNode.display = DisplayMode.Anonymous
    return layoutNode

  if node of tags.HTMLImageElement:
    let imageElement = HTMLImageElement(node)
    if *imageElement.src:
      layoutNode.imageContent = hash(&imageElement.src)
      layoutNode.imageBuffer = imageCache.getOrDefault(&imageElement.src)

  if node in style:
    # If we have a style for the DOM node, we can apply it to the layout node
    layoutNode.style = style[node]
    setStyleProperties(layoutNode, fontProvider)
  else:
    if node of dom.Element:
      warn "Element doesn't have defined style, it'll probably either render badly or not at all.",
        tag = Element(node).tagType

  ensureMove(layoutNode)

proc propagateStyles*(node: LayoutNode, style: StyleMap, fontProvider: FontProvider) =
  if node == nil:
    return

  setStyleProperties(node, fontProvider)

  var inheritedBodyProperties = false

  for child in node.children:
    if child.display == DisplayMode.Anonymous:
      # HACK: This is not how it works!
      const AvoidInheritance =
        [BorderAttr, BorderColorAttr, BorderStyleAttr, BorderWidthAttr]

      # Make anonymous nodes inherit their parent's style, besides some.
      for property, value in node.style:
        if property in AvoidInheritance:
          continue

        child.style[property] = value

    propagateStyles(child, style, fontProvider)

    # just a quirk in CSS
    # For documents whose root element is an HTML HTML element or an XHTML html element [HTML]:
    # if the computed value of background-image on the root element is none and its background-color is transparent, user agents must instead propagate the computed values of the background properties from that element’s first HTML BODY or XHTML body child element.
    #
    # https://www.w3.org/TR/css-backgrounds-3/#body-background
    if BackgroundColorAttr notin node.style and not inheritedBodyProperties and (
      node.domNode != nil and node.domNode of dom.Element and
      Element(node.domNode).tagType() == TAG_HTML
    ) and (
      child.domNode != nil and child.domNode of dom.Element and
      Element(child.domNode).tagType() == TAG_BODY
    ):
      inheritedBodyProperties = true
      node.backgroundColor = child.backgroundColor

proc buildLayoutTree*(
    node: dom.Node,
    style: StyleMap,
    fontProvider: FontProvider,
    imageCache: TableRef[string, pixie.Image],
): LayoutNode =
  let currentLayout = createLayoutNode(node, style, fontProvider, imageCache)
  # if currentLayout != nil:
  #  setStyleProperties(currentLayout)

  for child in node.childList:
    if child of dom.Comment:
      continue

    if child of dom.Element:
      let tag = Element(child).tagType
      if tag in [TAG_SCRIPT, TAG_STYLE, TAG_HEAD]:
        continue

    let childLayout = buildLayoutTree(child, style, fontProvider, imageCache)
    if childLayout != nil:
      currentLayout.children &= childLayout

  # setStyleProperties(currentLayout)
  currentLayout
