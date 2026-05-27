## fontconfig bindings
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

{.push header: "<fontconfig/fontconfig.h>".}

{.push importc.}

type
  FcChar8* = distinct uint8
  FcChar16* = distinct uint16
  FcChar32* = distinct uint32
  FcBool* = distinct int32

  FcType* = enum
    FcTypeUnknown = -1
    FcTypeVoid
    FcTypeInteger
    FcTypeDouble
    FcTypeString
    FcTypeBool
    FcTypeMatrix
    FcTypeCharSet
    FcTypeFTFace
    FcTypeLangSet
    FcTypeRange

  FcMatrix* = object
    xx*, xy*, yx*, yy*: float64

  FcObjectType* = object
    obj*: cstring
    typ*: FcType

  FcResult* = enum
    FcResultMatch
    FcResultNoMatch
    FcResultTypeMismatch
    FcResultNoId
    FcResultOutOfMemory

  FcMatchKind* = enum
    FcMatchPattern
    FcMatchFont
    FcMatchScan

  FcConfig* = object
  FcFileCache* = object
  FcBlanks* = object
  FcStrList* = object
  FcStrSet* = object
  FcCache* = object
  FcPattern* = object

let
  FC_MAJOR*, FC_MINOR*, FC_REVISION*: int32
  FC_VERSION*: int32
  FC_CACHE_VERSION_NUMBER*: int32

  FC_FAMILY*: cstring
  FC_STYLE*: cstring
  FC_SLANT*: cstring
  FC_WEIGHT*: cstring
  FC_SIZE*: cstring
  FC_ASPECT*: cstring
  FC_PIXEL_SIZE*: cstring
  FC_SPACING*: cstring
  FC_FOUNDRY*: cstring
  FC_ANTIALIAS*: cstring
  FC_HINTING*: cstring
  FC_HINT_STYLE*: cstring
  FC_VERTICAL_LAYOUT*: cstring
  FC_AUTOHINT*: cstring
  FC_GLOBAL_ADVANCE*: cstring
  FC_WIDTH*: cstring
  FC_FILE*: cstring
  FC_INDEX*: cstring
  FC_FT_FACE*: cstring
  FC_RASTERIZER*: cstring
  FC_OUTLINE*: cstring
  FC_SCALABLE*: cstring
  FC_COLOR*: cstring
  FC_VARIABLE*: cstring
  FC_SCALE*: cstring
  FC_SYMBOL*: cstring
  FC_DPI*: cstring
  FC_RGBA*: cstring
  FC_MINSPACE*: cstring
  FC_SOURCE*: cstring
  FC_CHARSET*: cstring
  FC_LANG*: cstring
  FC_FONTVERSION*: cstring
  FC_FULLNAME*: cstring
  FC_FAMILYLANG*: cstring
  FC_STYLELANG*: cstring
  FC_FULLNAMELANG*: cstring
  FC_CAPABILITY*: cstring
  FC_FONTFORMAT*: cstring
  FC_EMBOLDEN*: cstring
  FC_EMBEDDED_BITMAP*: cstring
  FC_DECORATIVE*: cstring
  FC_LCD_FILTER*: cstring
  FC_FONT_FEATURES*: cstring
  FC_FONT_VARIATIONS*: cstring
  FC_NAMELANG*: cstring
  FC_PRGNAME*: cstring
  FC_HASH*: cstring
  FC_POSTSCRIPT_NAME*: cstring
  FC_FONT_HAS_HINT*: cstring
  FC_ORDER*: cstring
  FC_DESKTOP_NAME*: cstring
  FC_NAMED_INSTANCE*: cstring
  FC_FONT_WRAPPER*: cstring

  FC_WEIGHT_THIN*: int32
  FC_WEIGHT_EXTRALIGHT*: int32
  FC_WEIGHT_ULTRALIGHT*: int32
  FC_WEIGHT_LIGHT*: int32
  FC_WEIGHT_DEMILIGHT*: int32
  FC_WEIGHT_SEMILIGHT*: int32
  FC_WEIGHT_BOOK*: int32
  FC_WEIGHT_REGULAR*: int32
  FC_WEIGHT_NORMAL*: int32
  FC_WEIGHT_MEDIUM*: int32
  FC_WEIGHT_DEMIBOLD*: int32
  FC_WEIGHT_SEMIBOLD*: int32
  FC_WEIGHT_BOLD*: int32
  FC_WEIGHT_EXTRABOLD*: int32
  FC_WEIGHT_ULTRABOLD*: int32
  FC_WEIGHT_BLACK*: int32
  FC_WEIGHT_HEAVY*: int32
  FC_WEIGHT_EXTRABLACK*: int32
  FC_WEIGHT_ULTRABLACK*: int32

  FC_SLANT_ROMAN*: int32
  FC_SLANT_ITALIC*: int32
  FC_SLANT_OBLIQUE*: int32

  FC_WIDTH_ULTRACONDENSED*: int32
  FC_WIDTH_EXTRACONDENSED*: int32
  FC_WIDTH_CONDENSED*: int32
  FC_WIDTH_SEMICONDENSED*: int32
  FC_WIDTH_NORMAL*: int32
  FC_WIDTH_SEMIEXPANDED*: int32
  FC_WIDTH_EXPANDED*: int32
  FC_WIDTH_EXTRAEXPANDED*: int32
  FC_WIDTH_ULTRAEXPANDED*: int32

  FC_PROPORTIONAL*: int32
  FC_DUAL*: int32
  FC_MONO*: int32
  FC_CHARCELL*: int32

  FC_RGBA_UNKNOWN*: int32
  FC_RGBA_RGB*: int32
  FC_RGBA_BGR*: int32
  FC_RGBA_VRGB*: int32
  FC_RGBA_VBGR*: int32
  FC_RGBA_NONE*: int32

  FC_HINT_NONE*: int32
  FC_HINT_SLIGHT*: int32
  FC_HINT_MEDIUM*: int32
  FC_HINT_FULL*: int32

  FC_LCD_NONE*: int32
  FC_LCD_DEFAULT*: int32
  FC_LCD_LIGHT*: int32
  FC_LCD_LEGACY*: int32

proc FcConfigDestroy*(c: ptr FcConfig)
proc FcInit*(): FcBool
proc FcFini*()
proc FcInitLoadConfigAndFonts*(): ptr FcConfig

proc FcNameParse*(name: cstring): ptr FcPattern
proc FcConfigSubstitute*(
  config: ptr FcConfig, pattern: ptr FcPattern, kind: FcMatchKind
): FcBool

proc FcDefaultSubstitute*(p: ptr FcPattern)

proc FcPatternGetString*(
  p: ptr FcPattern, obj: cstring, n: int32, s: ptr ptr FcChar8
): FcResult

proc FcPatternDestroy*(p: ptr FcPattern)

proc FcFontMatch*(
  config: ptr FcConfig, p: ptr FcPattern, res: ptr FcResult
): ptr FcPattern

{.pop.}

{.pop.}
