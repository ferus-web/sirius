## Cookie parser implementation
## 
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, strutils, sequtils, times]
import components/net/cookie, components/aux/parse_nums
import pkg/[url, results, shakar]

const ShortMonthNames* =
  ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

func isLeapYear(year: uint32): bool {.inline.} =
  year mod 4 == 0 and (year mod 100 != 0 or year mod 400 == 0)

func daysInMonth(year: uint32, month: uint32): uint32 {.inline.} =
  if month == 2:
    return (if isLeapYear(year): 29 else: 30)

  if month in {1, 3, 5, 7, 8, 10, 12}:
    return 31

  30

func parseCookieDateImpl(
    date: string
): Option[tuple[monthdayRange, month, year, hour, minute, second: uint32]] {.inline.} =
  ## https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis-22#section-5.1.1
  ##
  ## This is a separate routine just to isolate the side effects of the final step.
  var hour, minute, second, dayOfMonth, month, year: uint32

  func toUint(token: string, res: var uint32): bool =
    for c in token:
      if not isDigit(c):
        return false

    if (let value = tryParseUint(token, uint32); *value):
      res = &value
      true
    else:
      false

  func parseTime(token: string): bool =
    let parts = token.split(':')
    if parts.len != 3:
      return false

    for part in parts:
      if part.len == 0 or part.len > 2:
        return false

    toUint(parts[0], hour) and toUint(parts[1], minute) and toUint(parts[2], second)

  func parseDayOfMonth(token: string): bool =
    if token.len == 0 or token.len > 2:
      return false

    toUint(token, dayOfMonth)

  func parseMonth(token: string): bool =
    for i in 0 ..< 12:
      if cmpIgnoreCase(token, ShortMonthNames[i]) == 0:
        month = cast[uint32](i) + 1
        return true

    false

  func parseYear(token: string): bool =
    if token.len != 2 and token.len != 4:
      return false

    toUint(token, year)

  # 1. Using the grammar below, divide the cookie-date into date-tokens.
  let dateTokens = strutils
    .tokenize(
      date,
      {cast[char](0x09)} + {cast[char](0x20) .. cast[char](0x2f)} +
        {cast[char](0x3b) .. cast[char](0x40)} + {cast[char](0x5b) .. cast[char](0x60)} +
        {cast[char](0x7b) .. cast[char](0x7e)},
    )
    .toSeq()
    # tokenize() is so helpful here :D
    .mapIt(it.token)

  # 2. Process each date-token sequentially in the order the date-tokens appear in the cookie-date:
  var foundTime, foundDayOfMonth, foundMonth, foundYear: bool

  for token in dateTokens:
    # 1. If the found-time flag is not set and the token matches the time production, set the found-time flag and
    # set the hour-value, minute-value, and second-value to the numbers denoted by the digits in the date-token,
    # respectively. Skip the remaining sub-steps and continue to the next date-token.
    if not foundTime and parseTime(token):
      foundTime = true
    # 2. If the found-day-of-month flag is not set and the date-token matches the day-of-month production, set the
    # found-day-of-month flag and set the day-of-month-value to the number denoted by the date-token. Skip the
    # remaining sub-steps and continue to the next date-token.
    elif not foundDayOfMonth and parseDayOfMonth(token):
      foundDayOfMonth = true
    # 3. If the found-month flag is not set and the date-token matches the month production, set the found-month
    # flag and set the month-value to the month denoted by the date-token. Skip the remaining sub-steps and
    # continue to the next date-token.
    elif not foundMonth and parseMonth(token):
      foundMonth = true
    # 4. If the found-year flag is not set and the date-token matches the year production, set the found-year flag
    # and set the year-value to the number denoted by the date-token. Skip the remaining sub-steps and continue
    # to the next date-token.
    elif not foundYear and parseYear(token):
      foundYear = true

  # 3. If the year-value is greater than or equal to 70 and less than or equal to 99, increment the year-value by 1900.
  if year >= 70 and year <= 99:
    year += 1900

  # 4. If the year-value is greater than or equal to 0 and less than or equal to 69, increment the year-value by 2000.
  if year >= 0 and year <= 69:
    year += 2000

  # 5. Abort this algorithm and fail to parse the cookie-date if:
  # * at least one of the found-day-of-month, found-month, found-year, or found-time flags is not set,
  if not foundDayOfMonth or not foundMonth or not foundYear or not foundTime:
    return
  # * the day-of-month-value is less than 1 or greater than 31,
  if dayOfMonth < 1 or dayOfMonth > 31:
    return
  # * the year-value is less than 1601,
  if year < 1601:
    return
  # * the hour-value is greater than 23,
  if hour > 23:
    return
  # * the minute-value is greater than 59, or
  if minute > 59:
    return
  # * the second-value is greater than 59.
  if second > 59:
    return

  # 6. Let the parsed-cookie-date be the date whose day-of-month, month, year, hour, minute, and second (in UTC) are
  # the day-of-month-value, the month-value, the year-value, the hour-value, the minute-value, and the second-value,
  # respectively. If no such date exists, abort this algorithm and fail to parse the cookie-date.
  let monthdayRange = daysInMonth(year, month)
  if dayOfMonth > monthdayRange:
    return

  some(
    (
      monthdayRange: monthdayRange,
      month: month,
      year: year,
      hour: hour,
      minute: minute,
      second: second,
    )
  )

proc parseCookieDate*(date: string): Option[int64] =
  let parsed = parseCookieDateImpl(date)
  if !parsed:
    return none(int64)

  let (monthdayRange, month, year, hour, minute, second) = &parsed

  # 7. Return the parsed-cookie-date as the result of this algorithm.
  initDateTime(
    monthday = cast[times.MonthdayRange](monthdayRange),
    month = cast[times.Month](month),
    year = cast[int](year),
    hour = cast[times.HourRange](hour),
    minute = cast[times.MinuteRange](minute),
    second = cast[times.SecondRange](second),
    zone = utc(),
  )
    .toTime()
    .toUnix()
    .some()

func cookieContainsInvalidControlCharacter(
    cookieString: openArray[char]
): bool {.inline.} =
  for c in cookieString:
    let c = cast[uint8](c)

    if c <= 0x08'u8:
      return true

    if c >= 0x0a'u8 and c <= 0x1f'u8:
      return true

    if c == 0x7f'u8:
      return true

  false

proc handleExpiresAttribute(cookie: var Cookie, attribValue: string) =
  ## https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis-22#section-5.6.1
  let expiresTime = parseCookieDate(attribValue)
  if *expiresTime:
    cookie.expires = some(&expiresTime)

  # 2. If the attribute-value failed to parse as a cookie date, ignore the cookie-av
  if !cookie.expires:
    return

proc handleMaxAgeAttribute(cookie: var Cookie, attribValue: string) =
  # 1. If the attribute-value is empty, ignore the cookie-av.
  if attribValue.len < 1:
    return

  # 2. If the first character of the attribute-value is neither a DIGIT, nor a "-" character followed by a DIGIT, ignore the cookie-av.
  # 3. If the remainder of attribute-value contains a non-DIGIT character, ignore the cookie-av.
  let digits =
    if attribValue[0] == '-':
      attribValue[1 ..< attribValue.len]
    else:
      attribValue

  if digits.len < 1 or not digits.all(strutils.isDigit):
    return

  let deltaSeconds =
    if (let value = tryParseInt(attribValue); *value):
      &value
    else:
      (if attribValue[0] == '-': int64.low else: int64.high)

  cookie.maxAge = some(cast[int64](deltaSeconds))

proc handleDomainAttribute(
    cookie: var Cookie, attribValue: string
): Result[void, string] =
  # The domain-value is a subdomain as defined by Section 3.5 of [RFC1034], and as enhanced by Section 2.1 of [RFC1123].
  # Thus, domain-value is a string of [USASCII] characters, such as an "A-label" as defined in Section 2.3.2.1 of [RFC5890].

  # 1. Let cookie-domain be the attribute-value.
  var cookieDomain = attribValue

  # 2. If cookie-domain starts with %x2E ("."), let cookie-domain be cookie-domain without its leading %x2E (".").
  if cookieDomain.len > 1 and cookieDomain.startsWith('.'):
    cookieDomain = cookieDomain[1 ..< cookieDomain.len]

  # 3. Convert the cookie-domain to lower case.
  # 4. Append an attribute to the cookie-attribute-list with an attribute-name of Domain and an attribute-value of cookie-domain.
  cookie.domain = ensureMove(cookieDomain)

proc handlePathAttribute(url: url.URL, cookie: var Cookie, attribValue: string) =
  var cookiePath: string

  # 1. If the attribute-value is empty or if the first character of the attribute-value is not %x2F ("/"):
  if attribValue.len < 1 or attribValue[0] != '/':
    # 1. Let cookie-path be the default-path.
    cookiePath = url.pathname
  # Otherwise:
  else:
    # 1. Let cookie-path be the attribute-value.
    cookiePath = attribValue

  # 2. Append an attribute to the cookie-attribute-list with an attribute-name of Path and an attribute-value of cookie-path.
  cookie.path = ensureMove(cookiePath)

proc handleSecureAttribute(cookie: var Cookie) {.inline, raises: [].} =
  cookie.secure = true

proc handleHttpOnlyAttribute(cookie: var Cookie) {.inline, raises: [].} =
  cookie.httpOnly = true

func sameSiteFromString(mode: string): SameSite {.inline.} =
  let mode = toLowerAscii(mode)
  if mode == "none":
    SameSite.None
  elif mode == "strict":
    SameSite.Strict
  elif mode == "lax":
    SameSite.Lax
  else:
    SameSite.Default

proc handleSameSiteAttribute(cookie: var Cookie, attribValue: string) =
  # 1. Let enforcement be "Default".
  # 2. If cookie-av's attribute-value is a case-insensitive match for "None", set enforcement to "None".
  # 3. If cookie-av's attribute-value is a case-insensitive match for "Strict", set enforcement to "Strict".
  # 4. If cookie-av's attribute-value is a case-insensitive match for "Lax", set enforcement to "Lax".
  # 5. Append an attribute to the cookie-attribute-list with an attribute-name of "SameSite" and an attribute-value of enforcement.
  cookie.sameSite = sameSiteFromString(attribValue)

proc processAttribute(
    url: url.URL, cookie: var Cookie, attribName, attribValue: string
) =
  let attribName = toLowerAscii(attribName)
  if attribName == "expires":
    handleExpiresAttribute(cookie, attribValue)
  elif attribName == "max-age":
    handleMaxAgeAttribute(cookie, attribValue)
  elif attribName == "domain":
    # TODO: Maybe we can handle errors from this later.
    discard handleDomainAttribute(cookie, attribValue)
  elif attribName == "path":
    handlePathAttribute(url, cookie, attribValue)
  elif attribName == "secure":
    handleSecureAttribute(cookie)
  elif attribName == "httponly":
    handleHttpOnlyAttribute(cookie)
  elif attribName == "samesite":
    handleSameSiteAttribute(cookie, attribValue)

proc parseAttributes(url: url.URL, cookie: var Cookie, attribs: var string): bool =
  # 1. If the unparsed-attributes string is empty, skip the rest of these steps.
  if attribs.len < 1:
    return true

  # 2. Discard the first character of the unparsed-attributes (which will be a %x3B (";") character).
  attribs = attribs[1 ..< attribs.len]

  var cookieAv: string

  # 3. If the remaining unparsed-attributes contains a %x3B (";") character:
  if (let pos = attribs.find(';'); pos != -1):
    # 1. Consume the characters of the unparsed-attributes up to, but not including, the first %x3B (";") character.
    cookieAv = attribs[0 ..< pos]
    attribs = attribs[pos ..< attribs.len]
  # Otherwise:
  else:
    # 1. Consume the remainder of the unparsed-attributes.
    cookieAv = attribs
    attribs.setLen(0)

  # Let the cookie-av string be the characters consumed in this step; unparsed-attributes now contains any remaining characters
  var attribName, attribValue: string

  # 4. If the cookie-av string contains a %x3D ("=") character:
  if (let pos = cookieAv.find('='); pos != -1):
    # 1. The (possibly empty) attribute-name string consists of the characters up to, but not including, the first
    # %x3D ("=") character, and the (possibly empty) attribute-value string consists of the characters after the
    # first %x3D ("=") characters.
    attribName = cookieAv[0 ..< pos]
    if pos < cookieAv.len - 1:
      attribValue = cookieAv[pos + 1 ..< cookieAv.len]
  # Otherwise:
  else:
    # 1. The attribute-name string consists of the entire cookie-av string, and the attribute-value string is empty.
    attribName = cookieAv

  # 5. Remove any leading or trailing WSP characters from the attribute-name string and the attribute-value string.
  attribName = attribName.strip()
  attribValue = attribValue.strip()

  # 6. If the attribute-value is longer than 1024 octets, ignore the cookie-av string and return to Step 1 of this algorithm.
  if attribValue.len > 1024:
    return parseAttributes(url, cookie, attribs)

  # 7. Process the attribute-name and attribute-value according to the requirements in the following subsections.
  # (Notice that attributes with unrecognized attribute-names are ignored.)
  processAttribute(url, cookie, attribName, attribValue)

  # 8. Return to Step 1 of this algorithm.
  parseAttributes(url, cookie, attribs)

proc parseCookie*(url: url.URL, cookieString: string): Option[Cookie] =
  # 1. If the set-cookie-string contains a %x00-08 / %x0A-1F / %x7F character (CTL characters excluding HTAB):
  # Abort this algorithm and ignore the set-cookie-string entirely.
  if cookieContainsInvalidControlCharacter(cookieString):
    return none(Cookie)

  var
    nameValuePair: string
    unparsedAttributes: string

  # 2. If the set-cookie-string contains a %x3B (";") character:
  if (let pos = cookieString.find(';'); pos != -1):
    # 1. The name-value-pair string consists of the characters up to, but not including, the first %x3B (";"), and
    # the unparsed-attributes consist of the remainder of the set-cookie-string (including the %x3B (";") in question).
    nameValuePair = cookieString[0 ..< pos]
    unparsedAttributes = cookieString[pos ..< cookieString.len]
  # Otherwise:
  else:
    # 1. The name-value-pair string consists of all the characters contained in the set-cookie-string, and the
    # unparsed-attributes is the empty string.
    nameValuePair = cookieString

  var name, value: string

  # 3. If the name-value-pair string lacks a %x3D ("=") character, then the name string is empty, and the value
  # string is the value of name-value-pair.
  let posOfEquals = nameValuePair.find('=')
  if posOfEquals == -1:
    value = ensureMove(nameValuePair)
  else:
    name = nameValuePair[0 ..< posOfEquals]
    if posOfEquals < nameValuePair.len - 1:
      value = nameValuePair[posOfEquals + 1 ..< nameValuePair.len]

  # 4. Remove any leading or trailing WSP characters from the name string and the value string.
  name = name.strip()
  value = value.strip()

  # 5. If the sum of the lengths of the name string and the value string is more than 4096 octets, abort this
  if (name.len + value.len) > 4096:
    return none(Cookie)

  # 6. The cookie-name is the name string, and the cookie-value is the value string.
  var cookie = Cookie(
    creationTime: now().toTime().toUnix(),
    key: ensureMove(name),
    value: ensureMove(value),
  )

  if not parseAttributes(url, cookie, unparsedAttributes):
    return none(Cookie)

  some(ensureMove(cookie))
