## Types for resource loader
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[deques, tables]
import components/net/core

type
  FinalizeCallback* = proc(response: Response, err: TransportError)

  PendingAsset* = object
    finalize*: FinalizeCallback

  ResourceLoader* = ref object
    net*: NetworkClient
    pendingAssets*: Table[RequestID, PendingAsset]

    retryQueue*: Deque[tuple[spec: RequestSpec, asset: PendingAsset]]
