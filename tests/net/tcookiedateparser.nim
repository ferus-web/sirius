import components/aux/pretty, components/net/cookie_parser

print parseCookieDate("Sun, 06 Nov 2026 08:49:37 GMT")
print parseCookieDate("Wed, 15 Jul 2026 17:49:55 GMT")
print parseCookieDate("Friday, 17-Apr-2027 12:00:00 GMT")
print parseCookieDate("Sun, 6 Nov 2026 08:49:37 GMT")
print parseCookieDate("Wed, 20 Jan 2038 00:00:00 GMT")
