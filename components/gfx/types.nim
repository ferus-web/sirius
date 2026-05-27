import pkg/[nanovg, vmath]
import components/layout/[output_manager, types], components/os/fonts

type RenderingContext* = ref object
  vg*: nanovg.NVGContext
  renderSize*: vmath.Vec2
  tree*: LayoutNode

  outputManager*: OutputManager
  fontProvider*: FontProvider
