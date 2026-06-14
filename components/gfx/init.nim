import pkg/[chronicles, nanovg, vmath], pkg/surfer/backend/wayland/bindings/[egl, gles2]
import ./types

logScope:
  topics = "gfx/init"

proc newRenderingContext*(renderSize: vmath.Vec2): RenderingContext =
  debug "Creating new rendering context"
  nvgInit(eglGetProcAddress)

  debug "Initialized NanoVG, creating NVGContext"
  RenderingContext(vg: nvgCreateContext(), renderSize: renderSize)
