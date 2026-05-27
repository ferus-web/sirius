## Font loader implementation, plugs FontProvider into NanoVG
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options
import components/os/fonts
import pkg/[chronicles, nanovg]

logScope:
  topics = "gfx/font_loader"

proc getLoaderImplementation*(vg: nanovg.NVGContext): LoaderImplementation =
  LoaderImplementation(
    loadFont: proc(name: string, path: string): Option[fonts.Font] =
      debug "Parse and load font", name = name, path = path
      try:
        some(fonts.Font(name: name, impl: cast[int64](vg.createFont(name, path))))
      except nanovg.NVGError:
        error "Failed to load font!", name = name, path = path
        none(fonts.Font)
  )
