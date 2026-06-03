import std/tables
import pkg/[nanovg, pixie, vmath]
import components/layout/[output_manager, types], components/os/fonts

type RenderingContext* = ref object
  vg*: nanovg.NVGContext
  renderSize*: vmath.Vec2
  tree*: LayoutNode

  outputManager*: OutputManager
  fontProvider*: FontProvider

  viewerPosition*: vmath.Vec2
  imageTextures*: Table[pointer, nanovg.Image]
    # HACK: Very nasty hack to map pixie images to GPU framebuffers
    # (key is pixie::Image, which is a RC-backed pointer)

  paintDebugBounds*: bool
