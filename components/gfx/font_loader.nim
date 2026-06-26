## Font loader implementation, plugs FontProvider into FigDraw (pixie)
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, tables]
import components/os/fonts as osfonts
import pkg/[chronicles, vmath]
import pkg/figdraw/common/[fonttypes, fontutils, typefaces]

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
        font: osfonts.Font, availableSize: Vec2, fontSize: float32, text: string
    ): GlyphArrangement {.closure.} =
      typeset(
        rect(0, 0, availableSize.x, availableSize.y),
        [
          (
            FontStyle(
              font: FigFont(typefaceId: cast[TypefaceId](font.impl), size: fontSize)
            ),
            text,
          )
        ],
        hAlign = Left, # TODO: Probably should do something about these
        vAlign = Top, # same as above
        wrap = true,
        minContent = false,
      ),
  )
