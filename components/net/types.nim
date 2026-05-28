## Types for the network subsystem
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import pkg/curly

type
  HTTPMethod* {.pure, size: sizeof(uint8).} = enum
    GET = (0, "GET")

  NetworkClientObj = object
    ctx*: curly.Curly

  NetworkClient* = ref NetworkClientObj
