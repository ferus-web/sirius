## Routines for local assets
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, streams]

type
  AssetProviderImplementation* = object
    openAssetStream*: proc(name: string): Option[FileStream]

  AssetProviderObj = object
    impl: AssetProviderImplementation

  AssetProvider* = ref AssetProviderObj

proc openAssetStream*(provider: AssetProvider, name: string): Option[FileStream] =
  ## Resolve the path to the asset based off of its name, and return
  ## a read-only `FileStream` for it, if found. Otherwise, return
  ## an empty `Option[FileStream]`.
  assert(
    provider.impl.openAssetStream != nil, "openAssetStream not implemented in vtable"
  )

  provider.impl.openAssetStream(name)

proc initAssetProvider*(impl: AssetProviderImplementation): AssetProvider =
  AssetProvider(impl: impl)
