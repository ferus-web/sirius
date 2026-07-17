## Cookie jar implementation
## For now, this just writes a `cookies.json` to the working directory.
## I plan on writing a serialized KV store for this eventually (or maybe just using RocksDB).
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[algorithm, os, tables, times, sequtils]
import pkg/[chronicles, jsony, shakar, url]
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

func getExpiryDate(cookie: Cookie): int64 =
  if *cookie.maxAge:
    &cookie.maxAge + cookie.creationTime
  elif *cookie.expires:
    &cookie.expires
  else:
    unreachable
    0'i64

func isInvalidated(currentTime: int64, cookie: Cookie): bool =
  if !cookie.expires and !cookie.maxAge:
    return true

  let expiryDate = getExpiryDate(cookie)

  if currentTime >= expiryDate:
    return true

  false

proc match*(jar: CookieJar, url: url.URL): seq[Cookie] =
  if !url.hostname:
    return

  let
    domain = &url.hostname
    specialScheme = getSchemeType(url)
    secure = specialScheme == SchemeType.Https

  # TODO: Maybe we should move this to an argument and make this pure :p
  let currentTime = now().toTime().toUnix()

  if not jar.domains.contains(domain):
    return

  var matched = newSeqOfCap[Cookie](jar.domains[domain].len)
    # our best case is that all cookies are to be sent
  for i, cookie in reversed(jar.domains[domain]):
    if cookie.secure and not secure:
      continue

    if cookie.domain != domain:
      continue

    if cookie.path != url.pathname:
      continue

    if currentTime >= getExpiryDate(cookie):
      jar.domains[domain].delete(i)
      continue

    matched &= cookie

  ensureMove(matched)

proc collect*(jar: CookieJar) =
  ## Garbage-collect the cookie jar.
  ##
  ## This just evicts all cookies that are no longer valid.
  let currentTime = now().toTime().toUnix()

  for domain, cookies in jar.domains:
    for i, cookie in reversed(cookies):
      if isInvalidated(currentTime, cookie):
        jar.domains[domain].delete(i)

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
