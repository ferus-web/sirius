## Routines to parse data URL schemes
## Based on RFC 2397 (https://www.rfc-editor.org/rfc/rfc2397.html)
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[tables, options]
import components/impure/simdutf

type
  MediaType* = object
    typ*: string
    subtype*: string
    params*: Table[string, string]

  DataURL* = object
    mediaType*: MediaType
    base64*: bool
    data*: string

  ParserState {.pure, size: sizeof(uint8).} = enum
    Magic
    MediaType
    MediaSubtype
    ParamKey
    ParamValue
    Data

func decodeBase64*(url: DataURL): Option[string] =
  if not url.base64:
    return none(string)

  let
    opts = {Base64Options.DefaultAcceptGarbage}
    bufferSize =
      simdutf.base64LengthFromBinary(cast[uint64](url.data.len), options = opts)

  var
    buffer = newString(bufferSize)
    emissionCount = bufferSize

  let res = simdutf.base64ToBinarySafe(
    input = url.data[0].addr,
    length = cast[uint64](url.data.len),
    output = buffer[0].addr,
    outlen = emissionCount.addr,
    options = opts,
    lastChunkOptions = LastChunkHandlingOptions.Loose,
    decodeUpToBadChar = false,
  )

  if res.error != ErrorCode.Success:
    return none(string)

  some(ensureMove(buffer))

func parseDataURL*(buffer: string): Option[DataURL] =
  if buffer.len > cast[int64](uint32.high):
    return none(DataURL)
      # We do not wish to parse data URLs larger than 4GB. If they're _THAT_ big, you should probably not use them. ;^)

  var i = 0'u64
    # We use 64-bit ints internally for the position just to ensure we don't overflow.
  var state = ParserState.Magic
  let size = cast[uint64](buffer.len)

  var url: DataURL
  var paramKey, paramValue: string

  while i < size:
    case state
    of ParserState.Magic:
      if (size - i) < 5 or buffer[i] != 'd' or buffer[i + 1] != 'a' or
          buffer[i + 2] != 't' or buffer[i + 3] != 'a' or buffer[i + 4] != ':':
        # If the magic isn't "data:", abort.
        return none(DataURL)

      # Else, increment the pointer by 5 and set the state to MediaType.
      i += 5
      state = ParserState.MediaType
    of ParserState.MediaType:
      let c = buffer[i]
      inc i

      # If C is '/', set the state to MediaSubtype.
      if c == '/':
        state = ParserState.MediaSubtype
      else:
        # Otherwise, append C to the media type buffer.
        url.mediaType.typ &= c
    of ParserState.MediaSubtype:
      let c = buffer[i]
      inc i

      # If C is ';', set the state to ParamKey
      if c == ';':
        state = ParserState.ParamKey
      else:
        # Otherwise, append C to the media subtype buffer.
        url.mediaType.subtype &= c
    of ParserState.ParamKey:
      let c = buffer[i]
      inc i

      # If C is ';', set the state to ParamKey.
      if c == ';':
        # If paramKey is `base64`, set base64 to true.
        if paramKey == "base64":
          url.base64 = true

        # Otherwise, ignor eit.

        paramKey.reset()
      elif c == ',':
        # If C is ',', set the state to Data.
        state = ParserState.Data

        # If paramKey is `base64`, set base64 to true.
        if paramKey == "base64":
          url.base64 = true

        # Otherwise, ignor eit.
        paramKey.reset()
      elif c == '=':
        # If C is '=', set the state to ParamValue.
        state = ParserState.ParamValue
      else:
        # Else, append C to the parameter key buffer.
        paramKey &= c
    of ParserState.ParamValue:
      let c = buffer[i]
      inc i

      # If C is ';', set the state to ParamKey.
      if c == ';':
        url.mediaType.params[move(paramKey)] = move(paramValue)
      elif c == ',':
        # If C is ',', set the state to Data.
        state = ParserState.Data
      else:
        # Else, append C to the parameter value buffer.
        paramValue &= c
    of ParserState.Data:
      # Copy all remaining bytes to the data buffer,
      # and stop parsing.
      url.data.setLen(size - i)
      copyMem(url.data[0].addr, buffer[i].addr, url.data.len)

      break

  some(ensureMove(url))
