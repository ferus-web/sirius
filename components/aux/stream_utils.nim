## Utilities for operations on streams
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/streams
import components/impure/simdutf

func encodeBase64*(stream: StringStream): string =
  var buffer = newString(
    simdutf.base64LengthFromBinary(
      cast[uint64](stream.data.len), {Base64Options.DefaultAcceptGarbage}
    )
  )

  buffer.setLen(
    simdutf.binaryToBase64(
      stream.data[0].addr,
      cast[uint64](stream.data.len),
      buffer[0].addr,
      {Base64Options.DefaultAcceptGarbage},
    )
  )

  ensureMove(buffer)
