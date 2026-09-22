## Build flags that dictate certain engine behaviours
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

{.push intdefine: "Sirius$1".}
const MaximumConcurrentWebSocketConnections* = 16
  ## The maximum number of WebSocket connections that `WebSocketHostCallbacks::createWebSocket()` allows. I chose 16 mostly because if you require more WebSockets than that, the problem is your website and not the execution environment. :)
{.pop.}
