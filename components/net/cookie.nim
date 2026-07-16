## Cookie type and routines
## https://httpwg.org/specs/rfc6265.html
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options

type
  SameSite* {.pure, size: sizeof(uint8).} = enum
    Default = 0
    None
    Strict
    Lax

  Cookie* = object
    creationTime*: int64

    expires*: Option[int64]
    maxAge*: Option[int64]
    domain*, path*: string
    secure*, httpOnly*: bool
    sameSite*: SameSite

    key*, value*: string
