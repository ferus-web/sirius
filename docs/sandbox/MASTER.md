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
