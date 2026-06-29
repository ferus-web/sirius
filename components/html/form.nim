## Enums and routines for `<form>` and `<input>` elements
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)

type InputKind* {.pure, size: sizeof(uint8).} = enum
  ## https://html.spec.whatwg.org/#states-of-the-type-attribute
  Text = 0
  Search
  Telephone
  URL
  Email
  Password
  Date
  Month
  Week
  Time
  DatetimeLocal
  Number
  Range
  Color
  Checkbox
  Radio
  File
  Submit
  Image
  Reset
  Button
  Hidden
