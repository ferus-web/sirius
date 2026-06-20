import
  pkg/[chronicles, vmath],
  pkg/surfer/app,
  pkg/figdraw/[commons, fignodes, figrender],
  pkg/figdraw/common/fonttypes,
  pkg/figdraw/windowing/surfershim
import components/gfx/[painter, types]

logScope:
  topics = "gfx/init"

proc newRenderingContext*(app: App, renderSize: vmath.Vec2): RenderingContext =
  debug "Creating new rendering context"
  let ctx = RenderingContext(
    fig: newFigRenderer(atlasSize = 2048, backendState = SurferRenderBackend()),
    renderSize: renderSize,
  )

  surfershim.setupBackend(ctx.fig, app)
  drawTree(ctx)
    # We also need to push through an initial frame to start off the event chain

  ctx
