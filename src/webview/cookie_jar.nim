## Cookie jar implementation
## For now, this just writes a `cookies.json` to the working directory.
## I plan on writing a serialized KV store for this eventually (or maybe just using RocksDB).
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[os, tables, times]
import pkg/[chronicles, jsony]
import components/net/cookie

logScope:
  topics = "webview/cookie_jar"

const CookiesFile = "cookies.json"

type
  CookieJarObj = object
    domains*: Table[string, seq[Cookie]]

  CookieJar* = ref CookieJarObj

proc write*(jar: CookieJar) =
  writeFile(CookiesFile, toJson(jar))

proc insert*(jar: CookieJar, cookie: Cookie) =
  info "Inserting cookie in jar",
    creationTime = cookie.creationTime,
    expires = cookie.expires,
    maxAge = cookie.maxAge,
    domain = cookie.domain,
    path = cookie.path,
    secure = cookie.secure,
    httpOnly = cookie.httpOnly,
    sameSite = cookie.sameSite,
    key = cookie.key,
    value = cookie.value

  if jar.domains.contains(cookie.domain):
    jar.domains[cookie.domain] &= cookie
  else:
    jar.domains[cookie.domain] = @[cookie]

proc loadCookieJar*(): CookieJar =
  if not fileExists(CookiesFile):
    return CookieJar()

  fromJson(readFile(CookiesFile), CookieJar)
