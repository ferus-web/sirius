import std/[monotimes, deques, tables]
import pkg/[pixie, vmath], pkg/figdraw/[figrender, fignodes]
import components/layout/[output_manager, types], components/os/fonts

type RenderingContext* = ref object
  fig*: figrender.FigRenderer[int32]
  renderSize*: vmath.Vec2
  tree*: LayoutNode

  displayList*: fignodes.Renders
  rootNode*, transformNode*: FigIdx

  outputManager*: OutputManager
  fontProvider*: FontProvider

  viewerPosition*: vmath.Vec2
  scrollVelocity*: float32

  lastRender*: monotimes.MonoTime

  imageCache*: TableRef[string, pixie.Image]
  imageReuploadQueue*: Deque[string]

  paintDebugBounds*: bool
