import components/net/cookie_parser, components/aux/pretty
import pkg/url

let u = parseURL("https://example.com")
print parseCookie(
  u,
  "SID=31d4d96e407aad42; Path=/; Domain=example.com; Secure; HttpOnly; SameSite=Strict",
)
