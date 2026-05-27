## Routines for font detection and selection
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, tables]
import components/impure/fontconfig
import pkg/[chronicles, shakar]

logScope:
  topics = "os/fonts"

type
  Font* = object
    name*: string
    impl*: int64
      ## Implementation-specific tracking, just so we don't directly depend on NanoVG here.

  LoaderImplementation* = object ## Font-loading implementation vtable
    loadFont*: proc(name, path: string): Option[Font]

  FontProviderObj = object
    fcConfig*: ptr FcConfig

    loader: LoaderImplementation

    fontCache: Table[string, Font]
    familyCache: Table[string, string]

  FontProvider* = ref FontProviderObj

proc `=destroy`*(provider: var FontProviderObj) =
  if provider.fcConfig != nil:
    debug "Cleaning up FontProvider internals"

    FcConfigDestroy(provider.fcConfig)
    provider.fcConfig = nil

    FcFini()
  else:
    debug "Ignore ~FontProvider(); context is already invalid or cleaned up"

proc getFontByName*(provider: FontProvider, name: string): Option[Font] =
  assert(
    provider.fcConfig != nil,
    "FontProvider doesn't have a proper fontconfig context attached to it! (Was it initialized correctly?)",
  )

  # debug "Get font by name", name = name

  if provider.fontCache.contains(name):
    # debug "Returning cached font"
    return some(provider.fontCache[name])

  let pattern = FcNameParse(cstring(name))

  discard FcConfigSubstitute(provider.fcConfig, pattern, FcMatchPattern)
  FcDefaultSubstitute(pattern)

  var matchRes: FcResult
  let matchedFont = FcFontMatch(provider.fcConfig, pattern, matchRes.addr)

  if matchRes == FcResultMatch and matchedFont != nil:
    var
      fontFileName: ptr FcChar8
      fontFilePath: ptr FcChar8

    discard FcPatternGetString(matchedFont, FC_FULLNAME, 0, fontFileName.addr)

    if FcPatternGetString(matchedFont, FC_FILE, 0, fontFilePath.addr) == FcResultMatch:
      FcPatternDestroy(pattern)
      # FcPatternDestroy(matchedFont)
      let
        fontName = $cast[cstring](fontFileName)
        fontPath = $cast[cstring](fontFilePath)

      debug "Found font match by name", name = fontName, path = fontPath

      let loaded = provider.loader.loadFont(fontName, fontPath)
      if *loaded:
        provider.fontCache[name] = &loaded
      return loaded

  debug "Couldn't find font match by name"
  FcPatternDestroy(pattern)

proc getFontByFamily*(provider: FontProvider, family: string): Option[Font] =
  assert(
    provider.fcConfig != nil,
    "FontProvider doesn't have a proper fontconfig context attached to it! (Was it initialized correctly?)",
  )

  # debug "Get font by family", family = family

  if provider.familyCache.contains(family):
    # debug "Returning cached font"
    return provider.getFontByName(provider.familyCache[family])

  let pattern = FcNameParse(cstring(family))

  discard FcConfigSubstitute(provider.fcConfig, pattern, FcMatchPattern)
  FcDefaultSubstitute(pattern)

  var matchRes: FcResult
  let matchedFont = FcFontMatch(provider.fcConfig, pattern, matchRes.addr)

  if matchRes == FcResultMatch and matchedFont != nil:
    var fontFileName: ptr FcChar8

    if FcPatternGetString(matchedFont, FC_FULLNAME, 0, fontFileName.addr) ==
        FcResultMatch:
      FcPatternDestroy(pattern)
      # FcPatternDestroy(matchedFont)

      # OPTIMIZE: This is a bit wasteful.
      # We're calling fontconfig twice. But eh, I can't think of anything better right now.
      let nam = $cast[cstring](fontFileName)
      debug "Found candidate by family", name = nam

      provider.familyCache[family] = nam
      return provider.getFontByName(nam)

  debug "Couldn't find font match by family"
  FcPatternDestroy(pattern)

proc initFontProvider*(loader: LoaderImplementation): FontProvider =
  debug "Initialize fontconfig"
  assert(FcInit().bool, "Failed to initialize fontconfig backend for FontProvider!")

  FontProvider(loader: loader, fcConfig: FcInitLoadConfigAndFonts())
