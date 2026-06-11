## CSS types and enums for different specifications
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options

type
  ## Types for the CSS Text Decoration Module Level 3 specification
  ## https://www.w3.org/TR/css-text-decor-3
  TextDecorationLine* {.pure, size: sizeof(uint8).} = enum
    ## https://www.w3.org/TR/css-text-decor-3/#text-decoration-line-property
    None = 0
    Underline
    Overline
    LineThrough
    Blink # Deprecated.

  TextDecorationStyle* {.pure, size: sizeof(uint8).} = enum
    ## https://www.w3.org/TR/css-text-decor-3/#text-decoration-style-property
    Solid = 0
    Double
    Dotted
    Dashed
    Wavy

  TextUnderlineStyle* {.pure, size: sizeof(uint8).} = enum
    ## https://www.w3.org/TR/css-text-decor-3/#text-underline-position-property
    Auto = 0
    Under
    Left
    Right

  TextDecoration* = object
    ## https://www.w3.org/TR/css-text-decor-3/#text-decoration-property
    line*: TextDecorationLine
    style*: TextDecorationStyle
    underlineStyle*: TextUnderlineStyle # TODO: color for `text-decoration-color`
