## Routines and types for handling meta elements
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[strutils, strformat, options]
import components/dom/dom
import pkg/[results, shakar, url]

type
  HttpEquiv* {.pure, size: sizeof(uint8).} = enum
    ## https://html.spec.whatwg.org/#pragma-directives
    ContentLanguage = 0 ## Sets the pragma-set default language. 
    ContentType ## An alternative form of setting the charset.  
    DefaultStyle ## Sets the name of the default CSS style sheet set. 
    Refresh ## Acts as a timed redirect.
    SetCookie ## Has no effect. 
    XUACompatible
      ## In practice, encourages Internet Explorer to more closely follow the specifications.
    ContentSecurityPolicy ## Enforces a Content Security Policy on a Document.

  MetadataName* {.pure, size: sizeof(uint8).} = enum
    ## https://html.spec.whatwg.org/#standard-metadata-names
    ApplicationName = 0
    Author
    Description
    Generator
    Keywords
    Referrer
    ThemeColor
    ColorScheme

  RefreshData* = object
    time*: uint64
    urlRecord*: url.URL

func parseHttpEquiv*(value: string): Option[HttpEquiv] =
  let value = toLowerAscii(value)
  if value == "content-language":
    some(HttpEquiv.ContentLanguage)
  elif value == "content-type":
    some(HttpEquiv.ContentType)
  elif value == "default-style":
    some(HttpEquiv.DefaultStyle)
  elif value == "refresh":
    some(HttpEquiv.Refresh)
  elif value == "set-cookie":
    some(HttpEquiv.SetCookie)
  elif value == "x-ua-compatible":
    some(HttpEquiv.XUACompatible)
  elif value == "content-security-policy":
    some(HttpEquiv.ContentSecurityPolicy)
  else:
    none(HttpEquiv)

func parseMetadataName*(value: string): Option[MetadataName] =
  let value = toLowerAscii(value)
  if value == "application-name":
    some(MetadataName.ApplicationName)
  elif value == "author":
    some(MetadataName.Author)
  elif value == "description":
    some(MetadataName.Description)
  elif value == "generator":
    some(MetadataName.Generator)
  elif value == "keywords":
    some(MetadataName.Keywords)
  elif value == "referrer":
    some(MetadataName.Referrer)
  elif value == "theme-color":
    some(MetadataName.ThemeColor)
  elif value == "color-scheme":
    some(MetadataName.ColorScheme)
  else:
    none(MetadataName)

func parseRefreshData*(
    content: string, baseURL: Option[URL] = none(URL)
): Result[RefreshData, string] =
  ## Parse data for a timed redirect.
  ## https://html.spec.whatwg.org/#attr-meta-http-equiv-refresh

  # 1. If document's will declaratively refresh is true, then return.
  # NOTE: This step is ignored. It is up to the caller to manage this state.

  # 2. Let position point at the first code point of input.
  var pos: uint64
  let size = cast[uint64](content.len)

  template skipAscii() =
    while pos < size and content[pos] in strutils.Whitespace:
      # TODO: Would this benefit from SIMD in large refresh buffers? I'm not
      # sure if it'd be worth it to be honest...
      inc pos

  if size > cast[uint64](uint32.high):
    # NOTE: We will outright reject any inputs greater than 4GB. There is no reason for a Refresh to exceed 65536 bytes, much less *THAT* many bytes.
    return err("Refresh content data exceeds safe size")

  # 3. Skip ASCII whitespace within input given position.
  skipAscii()

  # 4. Let time be 0.
  var
    time: uint64
    timeString = newStringOfCap(4) # Preallocate for what I'd assume is the worst case

  # 5. Collect a sequence of code points that are ASCII digits from input given position, and let timeString be the result.
  while pos < size and content[pos] in strutils.Digits:
    timeString &= content[pos]
    inc pos

  # 6. If timeString is the empty string:
  if timeString.len < 1:
    # If the code point in input pointed to by position is not U+002E (.), then return.
    if pos < size and content[pos] != '.':
      return err(
        &"Expected a valid number or decimal point at position {pos}, got '{content[pos]}' instead."
      )

  # 7. Otherwise, set time to the result of parsing timeString using the rules for parsing non-negative integers.
  time = parseBiggestUint(ensureMove(timeString))

  # 8. Collect a sequence of code points that are ASCII digits and U+002E FULL STOP characters (.) from input given position. Ignore any collected characters.
  while pos < size and content[pos] in (strutils.Digits + {'.'}):
    inc pos

  # 9. Let urlRecord be document's URL.
  var urlRecord: URL

  # 10. If position is not past the end of input:
  if pos < size:
    # 1. If the code point in input pointed to by position is not U+003B (;), U+002C (,), or ASCII whitespace, then return.
    if content[pos] notin strutils.Whitespace and content[pos] != ';' and
        content[pos] != ',':
      return err(
        &"Expected whitespace, ';' or ',' at position {pos}, got '{content[pos]}' instead."
      )

    # 2. Skip ASCII whitespace within input given position.
    skipAscii()

    # 3. If the code point in input pointed to by position is U+003B (;) or U+002C (,), then advance position to the next code point.
    if pos < size and (content[pos] == ';' or content[pos] == ','):
      inc pos

    # 4. Skip ASCII whitespace within input given position.
    skipAscii()

  # 11. If position is not past the end of input:
  if pos < size:
    # 1. Let urlString be the substring of input from the code point at position to the end of the string.
    var urlString = content[cast[int64](pos) ..< content.len]
    var quote: Option[char]

    # 2. If the code point in input pointed to by position is U+0055 (U) or U+0075 (u), then advance position to the next code point. Otherwise, jump to the step labeled skip quotes.
    if pos < size and (content[pos] == 'U' or content[pos] == 'u'):
      inc pos
    else:
      # 8. Skip quotes: If the code point in input pointed to by position is U+0027 (') or U+0022 ("), then let quote be that code point, and advance position to the next code point. Otherwise, let quote be the empty string.
      if pos < size and (content[pos] == '\'' or content[pos] == '"'):
        quote = some(content[pos])
        inc pos

    func parseStep(): Result[RefreshData, string] =
      # 11. Parse: Set urlRecord to the result of encoding-parsing a URL given urlString, relative to document.
      let parsed = tryParseURL(urlString, baseURL)

      # 12. If urlRecord is failure, then return.
      if !parsed:
        return err(&"Cannot parse as URL: {urlString} ({parsed.error()})")

      urlRecord = &parsed

      # 13. If urlRecord's scheme is "javascript", then return.
      if urlRecord.scheme == "javascript":
        return err(&"URL record's scheme cannot be \"javascript\".")

      return ok(RefreshData(time: ensureMove(time), urlRecord: move(urlRecord)))

    # 3. If the code point in input pointed to by position is U+0052 (R) or U+0072 (r), then advance position to the next code point. Otherwise, jump to the step labeled parse.
    if pos < size and (content[pos] == 'R' or content[pos] == 'r'):
      inc pos
    else:
      return parseStep()

    # 4. If the code point in input pointed to by position is U+004C (L) or U+006C (l), then advance position to the next code point. Otherwise, jump to the step labeled parse.
    if pos < size and (content[pos] == 'L' or content[pos] == 'l'):
      inc pos
    else:
      return parseStep()

    # 5. Skip ASCII whitespace within input given position.
    skipAscii()

    # 6. If the code point in input pointed to by position is U+003D (=), then advance position to the next code point. Otherwise, jump to the step labeled parse.
    if content[pos] == '=':
      inc pos

    # 7. Skip ASCII whitespace within input given position.
    skipAscii()

    # 9. Set urlString to the substring of input from the code point at position to the end of the string.
    urlString = content[cast[int64](pos) ..< content.len]

    # 10. If quote is not the empty string, and there is a code point in urlString equal to quote, then truncate urlString at that code point, so that it and all subsequent code points are removed.
    if *quote:
      urlString = urlString[0 ..< urlString.find(&quote)]

    return parseStep()

  err(&"Expected URL, got EOF instead.")
