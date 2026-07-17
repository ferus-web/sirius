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

func serialize*(cookie: Cookie, last: bool = false): string {.inline.} =
  ## https://httpwg.org/http-extensions/draft-ietf-httpbis-rfc6265bis.html#section-5.8.3
  var buffer = newStringOfCap(
    cookie.key.len + cookie.value.len + cookie.domain.len + cookie.path.len + 32
  ) # super professional preallocation, this works. I guess.

  # 1. If the cookies' name is not empty, output the cookie's name followed by the %x3D ("=") character.
  if cookie.key.len > 0:
    buffer &= cookie.key
    buffer &= '='

  # 2. If the cookies' value is not empty, output the cookie's value.
  if cookie.value.len > 0:
    buffer &= cookie.value

  # 3. If the cookie was not the last cookie in the cookie-list, output the characters %x3B and %x20 ("; ").
  if not last:
    buffer &= "; "

  ensureMove(buffer)
