## Font loader implementation, plugs FontProvider into FigDraw (pixie)
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, tables]
import components/os/fonts as osfonts, components/css/types
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
        font: osfonts.Font,
        availableSize: Vec2,
        fontSize: float32,
        alignment: TextAlignment,
        text: string,
    ): GlyphArrangement {.closure.} =
      # TODO: Rename this to `measureGlyphArrangement` or something like that, this name has outgrown its job
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
        hAlign = (
          case alignment
          of TextAlignment.Start, TextAlignment.Left: FontHorizontal.Left
          of TextAlignment.End, TextAlignment.Right: FontHorizontal.Right
          of TextAlignment.Center: FontHorizontal.Center
          else: FontHorizontal.Left
        ),
          # TODO: Handle others, also the Start/End ones aren't computed correctly afaik.
        vAlign = Top, # TODO: Probably should do something about this
        wrap = true,
        minContent = false,
      ),
  )
