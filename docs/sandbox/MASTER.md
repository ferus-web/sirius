# Master IPC calls
**Author**: Trayambak Rai (`xtrayambak@disroot.org`)

## Renderer => Master
### frameDrawn
Sent by the Renderer in response to the master sending a `drawFrame`.
The master should not send any further frame-drawing requests until it receives this.

### useGraphicsFD
**Argument 1**: FD
Sent by the Renderer when it wants the master to present a particular DMA-BUF file descriptor via the browser's surface.

The first argument is a DMA-BUF file descriptor.

### targetResized
**Argument 1**: IVec2
**Argument 2**: uint32

Sent in acknowledgement to a `resizeRenderTarget` sent by the master.

The first argument specifies the new size of the buffer, and the second one specifies the stride as set by the GPU driver.

### setPageTitle
**Argument 1**: UTF-8 string

Sent when the renderer wants the master process to set this renderer's page's OS-specific window title. The master can choose to format this as it wishes to, or to ignore it entirely.

### setPCursorShape
**Argument 1**: `css::CursorPredefined`

Sent when the renderer believes the user is hovering over an element with a set predefined-cursor shape as per the CSS Basic UI Module Level 3 specifications. This does not support other variations of the `cursor` property.
