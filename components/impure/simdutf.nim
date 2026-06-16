## simdutf's C API bindings
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

{.push header: "<simdutf_c.h>".}

type
  ErrorCode* {.importc: "enum simdutf_error_code", pure, size: sizeof(int32).} = enum
    Success = 0
    HeaderBits
    TooShort
    TooLong
    Overlong
    TooLarge
    Surrogate
    InvalidBase64Character
    Base64InputRemainder
    Base64ExtraBits
    OutputBufferTooSmall
    Other

  SIMDUTFResult* {.importc: "struct simdutf_result".} = object
    error*: ErrorCode
    count*: uint64

  EncodingType* {.importc: "enum simdutf_encoding_type", pure, size: sizeof(int32).} = enum
    Unspecified = 0
    UTF8 = 1
    UTF16LE = 2
    UTF16BE = 4
    UTF32LE = 8
    UTF32BE = 16

  Base64Options* {.importc: "enum simdutf_base64_options", pure, size: sizeof(int32).} = enum
    Default = 0
    URL = 1
    DefaultNoPadding = 2
    URLWithPadding = 3
    DefaultAcceptGarbage = 4
    URLAcceptGarbage = 5
    DefaultOrURL = 8
    DefaultOrURLAcceptGarbage = 12

  LastChunkHandlingOptions* {.
    importc: "enum simdutf_last_chunk_handling_options", pure, size: sizeof(int32)
  .} = enum
    Loose = 0
    Strict = 1
    StopBeforePartial = 2
    OnlyFullChunks = 3

{.push importc: "simdutf_$1".}
func validate_utf8*(buf: ptr char, size: uint64): bool
func validate_utf8_with_errors*(buf: ptr char, size: uint64): SIMDUTFResult
func autodetect_encoding*(input: ptr char, size: uint64): EncodingType

func base64_to_binary*(
  input: cstring | ptr char,
  size: uint64,
  output: ptr char,
  options: set[Base64Options],
  lastChunkOptions: LastChunkHandlingOptions,
)
func base64_length_from_binary*(length: uint64, options: set[Base64Options]): uint64
func maximal_binary_length_from_base64*(
  input: cstring | ptr char, length: uint64
): uint64

func base64_to_binary_safe*(
  input: cstring | ptr char,
  length: uint64,
  output: ptr char,
  outlen: ptr uint64,
  options: set[Base64Options],
  lastChunkOptions: LastChunkHandlingOptions,
  decodeUpToBadChar: bool,
): SIMDUTFResult

func binary_to_base64*(
  input: cstring | ptr char,
  length: uint64,
  output: ptr char,
  options: set[Base64Options],
): uint64

func utf16_length_from_utf8*(input: cstring | ptr char, length: uint64): uint64
func convert_utf8_to_utf16*(
  input: cstring | ptr char, length: uint64, output: ptr uint16
): uint64

func validate_utf16*(buf: ptr uint16, size: uint64): bool
func validate_utf16le*(buf: ptr uint16, size: uint64): bool
func validate_utf16be*(buf: ptr uint16, size: uint64): bool

func count_utf8*(input: ptr char | cstring, length: uint64): uint64
func count_utf16*(input: ptr uint16, length: uint64): uint64
func count_utf16le*(input: ptr uint16, length: uint64): uint64
func count_utf16be*(input: ptr uint16, length: uint64): uint64

{.pop.}
