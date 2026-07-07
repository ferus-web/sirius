## CSS types and enums for different specifications
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options
import components/style/types
import pkg/chroma

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
    underlineStyle*: TextUnderlineStyle
    color*: Option[chroma.ColorRGBA]

type
  ## Types from the CSS Level 1 specification
  ## https://www.w3.org/TR/CSS1
  FloatMode* {.pure, size: sizeof(uint8).} = enum
    ## https://www.w3.org/TR/CSS1/#float
    None = 0
    Left
    Right

  BorderStyle* {.pure, size: sizeof(uint8).} = enum
    ## https://www.w3.org/TR/CSS1/#border-style
    None = 0
    Dotted
    Dashed
    Solid
    Double
    Groove
    Ridge
    Inset
    Outset

  Border* = object ## https://www.w3.org/TR/CSS1/#border
    width*: Option[CSSValue]
    style*: Option[BorderStyle]
    color*: Option[chroma.ColorRGBA]

type
  ## Types for the CSS Text Module Level 3 specification
  ## https://www.w3.org/TR/css-text-3
  Whitespace* {.pure, size: sizeof(uint8).} = enum
    ## https://www.w3.org/TR/css-text-3/#white-space-property
    Normal = 0
    Pre
    NoWrap
    PreWrap
    BreakSpaces
    PreLine

  TextAlignment* {.pure, size: sizeof(uint8).} = enum
    ## https://www.w3.org/TR/css-text-3/#justification
    Start = 0
    End
    Left
    Right
    Center
    Justify
    MatchParent
    JustifyAll
