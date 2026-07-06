## Known MIME types
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[options, strutils, tables]

type MimeType* {.pure, size: sizeof(uint8).} = enum
  HTML
  CSS
  JavaScript
  JPEG
  PNG
  GIF
  WebP

const MimeMap = toTable {
  "text/html": MimeType.HTML,
  "text/css": MimeType.CSS,
  "text/javascript": MimeType.JavaScript,
  "application/javascript": MimeType.JavaScript,
  "application/x-javascript": MimeType.JavaScript,
  "image/png": MimeType.PNG,
  "image/jpeg": MimeType.JPEG,
  "image/jpg": MimeType.JPEG,
  "image/gif": MimeType.GIF,
  "image/webp": MimeType.WebP,
}

func getMimeType*(value: string): Option[MimeType] =
  let value = toLowerAscii(value)
  if MimeMap.contains(value):
    return some(MimeMap[value])

  # TODO: Handle more complex mime types and charset keys
