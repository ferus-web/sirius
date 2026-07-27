## Enums and types for `<form>` and `<input>` elements
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[strutils, options]

type
  InputKind* {.pure, size: sizeof(uint8).} = enum
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

  FormMethod* {.pure, size: sizeof(uint8).} = enum
    Get
    Post
    Dialog

func parseFormMethod*(value: string): Option[FormMethod] =
  let value = toLowerAscii(value)
  if value == "get":
    some(FormMethod.Get)
  elif value == "post":
    some(FormMethod.Post)
  elif value == "dialog":
    some(FormMethod.Dialog)
  else:
    none(FormMethod)

func parseInputKind*(value: string): Option[InputKind] =
  let value = toLowerAscii(value)
  if value == "text":
    some(InputKind.Text)
  elif value == "search":
    some(InputKind.Search)
  elif value == "telephone":
    some(InputKind.Telephone)
  elif value == "url":
    some(InputKind.URL)
  elif value == "email":
    some(InputKind.Email)
  elif value == "password":
    some(InputKind.Password)
  elif value == "date":
    some(InputKind.Date)
  elif value == "month":
    some(InputKind.Month)
  elif value == "week":
    some(InputKind.Week)
  elif value == "time":
    some(InputKind.Time)
  elif value == "datetime-local":
    some(InputKind.DatetimeLocal)
  elif value == "number":
    some(InputKind.Number)
  elif value == "range":
    some(InputKind.Range)
  elif value == "color":
    some(InputKind.Color)
  elif value == "checkbox":
    some(InputKind.Checkbox)
  elif value == "radio":
    some(InputKind.Radio)
  elif value == "file":
    some(InputKind.File)
  elif value == "submit":
    some(InputKind.Submit)
  elif value == "image":
    some(InputKind.Image)
  elif value == "reset":
    some(InputKind.Reset)
  elif value == "button":
    some(InputKind.Button)
  elif value == "hidden":
    some(InputKind.Hidden)
  else:
    none(InputKind)
