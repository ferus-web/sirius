# Renderer IPC calls
**Author**: Trayambak Rai (`xtrayambak@disroot.org`)

## Master => Renderer
### gotoURL
**Argument 1**: URL

Sent when the master process wants this renderer to navigate to a particular URL.

### close
Sent when the master process wants this renderer to exit.

## Renderer => Master
### setPageTitle
**Argument 1**: UTF-8 string

Sent when the renderer wants the master process to set this renderer's page's title
