## `OutputManager` essentially lets CSS units translate to roughly what the user _should_ see
## on the screen. It requires OS integration eventually.
## 
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/options
import pkg/shakar
import components/style/types

type OutputManager* = ref object
  pixelsPerInch*: float32 = 96.0f

func computePixels*(manager: OutputManager, value: CSSValue): float32 =
  if value.kind != CSSValueKind.Dimension:
    assert off, $value.kind
    return 0'f32 # FIXME: Not compliant. I think.

  case value.dim.unit
  of CSSUnit.Px:
    return value.dim.value
  of CSSUnit.Mm:
    return (value.dim.value * manager.pixelsPerInch) / 25.4
  of CSSUnit.Cm:
    return (value.dim.value * manager.pixelsPerInch) / 2.54
  of CSSUnit.In:
    return value.dim.value * manager.pixelsPerInch
  of CSSUnit.Percent:
    unreachable
