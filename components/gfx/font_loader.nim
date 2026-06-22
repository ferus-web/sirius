## Font loader implementation, plugs FontProvider into FigDraw (pixie)
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, tables]
import components/os/fonts as osfonts
import pkg/[chronicles, pixie, vmath]
import pkg/figdraw/common/[fonttypes, typefaces]

logScope:
  topics = "gfx/font_loader"

proc getLoaderImplementation*(): LoaderImplementation =
  LoaderImplementation(
    loadFont: proc(name: string, path: string): Option[osfonts.Font] =
      debug "Parse and load font", name = name, path = path
      try:
        some(
          osfonts.Font(
            name: name,
            impl: cast[int64](loadTypeface(name, readFile(path), TypeFaceKinds.TTF)),
          )
        ) # TODO: .otf files
      except: # TODO: Find the exception for this...
        error "Failed to load font!", name = name, path = path
        none(osfonts.Font),
    measureTextBounds: proc(
        font: osfonts.Font, size: float32, text: string
    ): vmath.Vec2 =
      # XXX: Should we really be plugging into pixie?
      # Hopefully it's accurate enough for now, it's probably better than the 0.65'f32 hack anyways
      let font = newFont(typefaceTable[cast[TypefaceId](font.impl)])
      font.size = size

      typeset(font, text).layoutBounds(),
  )
