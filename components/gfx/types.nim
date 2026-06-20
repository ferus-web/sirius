import std/[monotimes, tables]
import
  pkg/[pixie, vmath],
  pkg/figdraw/[figrender, fignodes],
  pkg/figdraw/windowing/surfershim
    # FIXME: We should probably not rely on surfer so much. Make this a compile time toggle sometime later? Or maybe not if we don't ever get the GTK4 frontend.
import components/layout/[output_manager, types], components/os/fonts

type RenderingContext* = ref object
  fig*: figrender.FigRenderer[SurferRenderBackend]
  renderSize*: vmath.Vec2
  tree*: LayoutNode

  displayList*: fignodes.Renders

  outputManager*: OutputManager
  fontProvider*: FontProvider

  viewerPosition*: vmath.Vec2
  scrollVelocity*: float32

  lastRender*: monotimes.MonoTime

  # imageTextures*: Table[pointer, nanovg.Image]
  # HACK: Very nasty hack to map pixie images to GPU framebuffers
  # (key is pixie::Image, which is a RC-backed pointer)
  paintDebugBounds*: bool
