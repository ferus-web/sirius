import
  pkg/[chronicles, vmath],
  pkg/figdraw/[commons, fignodes, figrender],
  pkg/figdraw/common/fonttypes
import components/gfx/[painter, types]

logScope:
  topics = "gfx/init"

proc newRenderingContext*(renderSize: vmath.Vec2): RenderingContext =
  debug "Creating new rendering context"
  let ctx = RenderingContext(
    fig: newFigRenderer(atlasSize = 2048, backendState = 0'i32), renderSize: renderSize
  )

  # drawTree(ctx)
  # We also need to push through an initial frame to start off the event chain

  ctx
