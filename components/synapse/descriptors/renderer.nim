## *Generated automatically by scanner. Do not edit!*
## **Source**: ipc/renderer.ipdl
import std/options
import components/synapse/[encoder, types]
import components/synapse/master
import pkg/vmath
import pkg/[results, shakar]
import pkg/url

type RenderOp* {.pure, size: sizeof(uint16).} = enum
  GotoURL = 0
  DrawFrame = 1
  ResizeRenderTarget = 2
  Close = 3
  ViewportScroll = 4
  CursorMotion = 5
  CursorClick = 6
  KeyPressed = 7
  SendGraphicsFD = 8
  Exit = 9
  ClipboardWriteAck = 10
  ClipboardWriteNack = 11
  ClipboardReadAck = 12
  ClipboardReadNack = 13
  InsertScript = 14

# Sender API

proc gotoURL*(ctx: Master, tab: uint32, target: url.URL) =
  ctx.encoder.encode(RenderOp.GotoURL)
  ctx.encoder.push(target)
  ctx.send(&ctx.tabs[tab].renderer())

proc drawFrame*(ctx: Master, tab: uint32) =
  ctx.encoder.encode(RenderOp.DrawFrame)
  ctx.send(&ctx.tabs[tab].renderer())

proc resizeRenderTarget*(ctx: Master, tab: uint32, size: vmath.IVec2) =
  ctx.encoder.encode(RenderOp.ResizeRenderTarget)
  ctx.encoder.push(size)
  ctx.send(&ctx.tabs[tab].renderer())

proc close*(ctx: Master, tab: uint32) =
  ctx.encoder.encode(RenderOp.Close)
  ctx.send(&ctx.tabs[tab].renderer())

proc viewportScroll*(ctx: Master, tab: uint32, velocity: vmath.Vec2) =
  ctx.encoder.encode(RenderOp.ViewportScroll)
  ctx.encoder.push(velocity)
  ctx.send(&ctx.tabs[tab].renderer())

proc cursorMotion*(ctx: Master, tab: uint32, position: vmath.Vec2) =
  ctx.encoder.encode(RenderOp.CursorMotion)
  ctx.encoder.push(position)
  ctx.send(&ctx.tabs[tab].renderer())

proc cursorClick*(ctx: Master, tab: uint32) =
  ctx.encoder.encode(RenderOp.CursorClick)
  ctx.send(&ctx.tabs[tab].renderer())

proc keyPressed*(ctx: Master, tab: uint32, key: string, keycode: string, repeat: bool) =
  ctx.encoder.encode(RenderOp.KeyPressed)
  ctx.encoder.push(key)
  ctx.encoder.push(keycode)
  ctx.encoder.push(repeat)
  ctx.send(&ctx.tabs[tab].renderer())

proc sendGraphicsFD*(ctx: Master, tab: uint32) =
  ctx.encoder.encode(RenderOp.SendGraphicsFD)
  ctx.send(&ctx.tabs[tab].renderer())

proc exit*(ctx: Master, tab: uint32) =
  ctx.encoder.encode(RenderOp.Exit)
  ctx.send(&ctx.tabs[tab].renderer())

proc clipboardWriteAck*(ctx: Master, tab: uint32, promiseId: uint32) =
  ctx.encoder.encode(RenderOp.ClipboardWriteAck)
  ctx.encoder.push(promiseId)
  ctx.send(&ctx.tabs[tab].renderer())

proc clipboardWriteNack*(ctx: Master, tab: uint32, promiseId: uint32) =
  ctx.encoder.encode(RenderOp.ClipboardWriteNack)
  ctx.encoder.push(promiseId)
  ctx.send(&ctx.tabs[tab].renderer())

proc clipboardReadAck*(ctx: Master, tab: uint32, promiseId: uint32, data: string) =
  ctx.encoder.encode(RenderOp.ClipboardReadAck)
  ctx.encoder.push(promiseId)
  ctx.encoder.push(data)
  ctx.send(&ctx.tabs[tab].renderer())

proc clipboardReadNack*(ctx: Master, tab: uint32, promiseId: uint32) =
  ctx.encoder.encode(RenderOp.ClipboardReadNack)
  ctx.encoder.push(promiseId)
  ctx.send(&ctx.tabs[tab].renderer())

proc insertScript*(ctx: Master, tab: uint32, baseURL: url.URL, code: string) =
  ctx.encoder.encode(RenderOp.InsertScript)
  ctx.encoder.push(baseURL)
  ctx.encoder.push(code)
  ctx.send(&ctx.tabs[tab].renderer())

# Recipient API
type
  GotoURLParams* = object
    target*: url.URL

  DrawFrameParams* = object

  ResizeRenderTargetParams* = object
    size*: vmath.IVec2

  CloseParams* = object

  ViewportScrollParams* = object
    velocity*: vmath.Vec2

  CursorMotionParams* = object
    position*: vmath.Vec2

  CursorClickParams* = object

  KeyPressedParams* = object
    key*: string
    keycode*: string
    repeat*: bool

  SendGraphicsFDParams* = object

  ExitParams* = object

  ClipboardWriteAckParams* = object
    promiseId*: uint32

  ClipboardWriteNackParams* = object
    promiseId*: uint32

  ClipboardReadAckParams* = object
    promiseId*: uint32
    data*: string

  ClipboardReadNackParams* = object
    promiseId*: uint32

  InsertScriptParams* = object
    baseURL*: url.URL
    code*: string

proc params*[T: object](msg: Message[RenderOp], _: typedesc[T]): Result[T, string] =
  var params: T

  when T is GotoURLParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"GotoURL: Argument count mismatch")

    let targetOpt = msg.argument(0, url.URL)
    if !targetOpt:
      return err("GotoURL: Missing non-optional argument 'target' (URL) at position 0")
    else:
      params.target = &targetOpt

  when T is DrawFrameParams:
    # argc [high]: 0; argc [low]: 0

    if msg.argc > 0'u8 or msg.argc < 0'u8:
      return err(&"DrawFrame: Argument count mismatch")

  when T is ResizeRenderTargetParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"ResizeRenderTarget: Argument count mismatch")

    let sizeOpt = msg.argument(0, vmath.IVec2)
    if !sizeOpt:
      return err(
        "ResizeRenderTarget: Missing non-optional argument 'size' (IVec2) at position 0"
      )
    else:
      params.size = &sizeOpt

  when T is CloseParams:
    # argc [high]: 0; argc [low]: 0

    if msg.argc > 0'u8 or msg.argc < 0'u8:
      return err(&"Close: Argument count mismatch")

  when T is ViewportScrollParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"ViewportScroll: Argument count mismatch")

    let velocityOpt = msg.argument(0, vmath.Vec2)
    if !velocityOpt:
      return err(
        "ViewportScroll: Missing non-optional argument 'velocity' (Vec2) at position 0"
      )
    else:
      params.velocity = &velocityOpt

  when T is CursorMotionParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"CursorMotion: Argument count mismatch")

    let positionOpt = msg.argument(0, vmath.Vec2)
    if !positionOpt:
      return err(
        "CursorMotion: Missing non-optional argument 'position' (Vec2) at position 0"
      )
    else:
      params.position = &positionOpt

  when T is CursorClickParams:
    # argc [high]: 0; argc [low]: 0

    if msg.argc > 0'u8 or msg.argc < 0'u8:
      return err(&"CursorClick: Argument count mismatch")

  when T is KeyPressedParams:
    # argc [high]: 3; argc [low]: 3

    if msg.argc > 3'u8 or msg.argc < 3'u8:
      return err(&"KeyPressed: Argument count mismatch")

    let keyOpt = msg.argument(0, string)
    if !keyOpt:
      return
        err("KeyPressed: Missing non-optional argument 'key' (String) at position 0")
    else:
      params.key = &keyOpt
    let keycodeOpt = msg.argument(1, string)
    if !keycodeOpt:
      return err(
        "KeyPressed: Missing non-optional argument 'keycode' (String) at position 1"
      )
    else:
      params.keycode = &keycodeOpt
    let repeatOpt = msg.argument(2, bool)
    if !repeatOpt:
      return
        err("KeyPressed: Missing non-optional argument 'repeat' (Bool) at position 2")
    else:
      params.repeat = &repeatOpt

  when T is SendGraphicsFDParams:
    # argc [high]: 0; argc [low]: 0

    if msg.argc > 0'u8 or msg.argc < 0'u8:
      return err(&"SendGraphicsFD: Argument count mismatch")

  when T is ExitParams:
    # argc [high]: 0; argc [low]: 0

    if msg.argc > 0'u8 or msg.argc < 0'u8:
      return err(&"Exit: Argument count mismatch")

  when T is ClipboardWriteAckParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"ClipboardWriteAck: Argument count mismatch")

    let promiseIdOpt = msg.argument(0, uint32)
    if !promiseIdOpt:
      return err(
        "ClipboardWriteAck: Missing non-optional argument 'promiseId' (Uint32) at position 0"
      )
    else:
      params.promiseId = &promiseIdOpt

  when T is ClipboardWriteNackParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"ClipboardWriteNack: Argument count mismatch")

    let promiseIdOpt = msg.argument(0, uint32)
    if !promiseIdOpt:
      return err(
        "ClipboardWriteNack: Missing non-optional argument 'promiseId' (Uint32) at position 0"
      )
    else:
      params.promiseId = &promiseIdOpt

  when T is ClipboardReadAckParams:
    # argc [high]: 2; argc [low]: 2

    if msg.argc > 2'u8 or msg.argc < 2'u8:
      return err(&"ClipboardReadAck: Argument count mismatch")

    let promiseIdOpt = msg.argument(0, uint32)
    if !promiseIdOpt:
      return err(
        "ClipboardReadAck: Missing non-optional argument 'promiseId' (Uint32) at position 0"
      )
    else:
      params.promiseId = &promiseIdOpt
    let dataOpt = msg.argument(1, string)
    if !dataOpt:
      return err(
        "ClipboardReadAck: Missing non-optional argument 'data' (String) at position 1"
      )
    else:
      params.data = &dataOpt

  when T is ClipboardReadNackParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"ClipboardReadNack: Argument count mismatch")

    let promiseIdOpt = msg.argument(0, uint32)
    if !promiseIdOpt:
      return err(
        "ClipboardReadNack: Missing non-optional argument 'promiseId' (Uint32) at position 0"
      )
    else:
      params.promiseId = &promiseIdOpt

  when T is InsertScriptParams:
    # argc [high]: 2; argc [low]: 2

    if msg.argc > 2'u8 or msg.argc < 2'u8:
      return err(&"InsertScript: Argument count mismatch")

    let baseURLOpt = msg.argument(0, url.URL)
    if !baseURLOpt:
      return
        err("InsertScript: Missing non-optional argument 'baseURL' (URL) at position 0")
    else:
      params.baseURL = &baseURLOpt
    let codeOpt = msg.argument(1, string)
    if !codeOpt:
      return
        err("InsertScript: Missing non-optional argument 'code' (String) at position 1")
    else:
      params.code = &codeOpt

  ok(ensureMove(params))
