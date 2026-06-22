## Font loader implementation, plugs FontProvider into FigDraw (pixie)
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options
import components/os/fonts as osfonts
import pkg/chronicles
import pkg/figdraw/common/typefaces

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
        none(osfonts.Font)
  )
