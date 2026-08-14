# Renderer IPC calls
**Author**: Trayambak Rai (`xtrayambak@disroot.org`)

## Master => Renderer
### gotoURL
**Argument 1**: string

Sent when the master process wants this renderer to navigate to a particular URL.

### close
Sent when the master process wants this renderer to exit.

### drawFrame
Sent when the master process wants the WebRenderer to composite a new frame.

### resizeRenderTarget
Sent when the master process wants the WebRenderer to resize its rendering buffer. This is generally called when the browser viewport is resized.

### viewportScroll
**Argument 1**: Vec2

Sent by the master process when it wants the viewport to scroll in or away from a particular direction, as signalled by argument 1 (velocity).

### cursorMotion
**Argument 1**: Vec2

Sent when the user moves their cursor around in the browser.

**Note**: Argument 1 (position) contains the coordinates relative to the viewport, so it can be directly applied to the rendered scene without accounting for the browser chrome.
