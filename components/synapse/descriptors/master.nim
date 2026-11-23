## *Generated automatically by scanner. Do not edit!*
## **Source**: ipc/master.ipdl
import std/options
import components/synapse/[encoder, types]
import components/synapse/client
import pkg/vmath
import pkg/[results, shakar]
import pkg/url

type MasterOp* {.pure, size: sizeof(uint16).} = enum
  FrameDrawn = 0
  UseGraphicsFD = 1
  TargetResized = 2
  SetPageTitle = 3
  SetPCursorShape = 4
  AlertMessage = 5
  UpdateNavigation = 6
  UpdateStatusBar = 7
  ClipboardWriteText = 8
  ClipboardReadText = 9
  CallEmbedBinding = 10
  ProcessSpawned = 11

# Sender API

proc frameDrawn*(ctx: Client) =
  ctx.encoder.encode(MasterOp.FrameDrawn)
  ctx.send()

proc useGraphicsFD*(ctx: Client, dma: FileDescriptor) =
  ctx.encoder.encode(MasterOp.UseGraphicsFD)
  ctx.encoder.push(dma)
  ctx.send()

proc targetResized*(ctx: Client, renderSize: vmath.IVec2, stride: uint32) =
  ctx.encoder.encode(MasterOp.TargetResized)
  ctx.encoder.push(renderSize)
  ctx.encoder.push(stride)
  ctx.send()

proc setPageTitle*(ctx: Client, title: string) =
  ctx.encoder.encode(MasterOp.SetPageTitle)
  ctx.encoder.push(title)
  ctx.send()

proc setPCursorShape*(ctx: Client, predef: uint8) =
  ctx.encoder.encode(MasterOp.SetPCursorShape)
  ctx.encoder.push(predef)
  ctx.send()

proc alertMessage*(ctx: Client, text: Option[string]) =
  ctx.encoder.encode(MasterOp.AlertMessage)
  if *text:
    ctx.encoder.push(text)
  ctx.send()

proc updateNavigation*(ctx: Client, location: url.URL) =
  ctx.encoder.encode(MasterOp.UpdateNavigation)
  ctx.encoder.push(location)
  ctx.send()

proc updateStatusBar*(ctx: Client, text: string) =
  ctx.encoder.encode(MasterOp.UpdateStatusBar)
  ctx.encoder.push(text)
  ctx.send()

proc clipboardWriteText*(ctx: Client, textData: string, promiseId: uint32) =
  ctx.encoder.encode(MasterOp.ClipboardWriteText)
  ctx.encoder.push(textData)
  ctx.encoder.push(promiseId)
  ctx.send()

proc clipboardReadText*(ctx: Client, promiseId: uint32) =
  ctx.encoder.encode(MasterOp.ClipboardReadText)
  ctx.encoder.push(promiseId)
  ctx.send()

proc callEmbedBinding*(ctx: Client, routine: string) =
  ctx.encoder.encode(MasterOp.CallEmbedBinding)
  ctx.encoder.push(routine)
  ctx.send()

proc processSpawned*(ctx: Client, identifier: uint64, pidfd: FileDescriptor) =
  ctx.encoder.encode(MasterOp.ProcessSpawned)
  ctx.encoder.push(identifier)
  ctx.encoder.push(pidfd)
  ctx.send()

# Recipient API
type
  FrameDrawnParams* = object

  UseGraphicsFDParams* = object
    dma*: FileDescriptor

  TargetResizedParams* = object
    renderSize*: vmath.IVec2
    stride*: uint32

  SetPageTitleParams* = object
    title*: string

  SetPCursorShapeParams* = object
    predef*: uint8

  AlertMessageParams* = object
    text*: Option[string]

  UpdateNavigationParams* = object
    location*: url.URL

  UpdateStatusBarParams* = object
    text*: string

  ClipboardWriteTextParams* = object
    textData*: string
    promiseId*: uint32

  ClipboardReadTextParams* = object
    promiseId*: uint32

  CallEmbedBindingParams* = object
    routine*: string

  ProcessSpawnedParams* = object
    identifier*: uint64
    pidfd*: FileDescriptor

proc params*[T: object](msg: Message[MasterOp], _: typedesc[T]): Result[T, string] =
  var params: T

  when T is FrameDrawnParams:
    # argc [high]: 0; argc [low]: 0

    if msg.argc > 0'u8 or msg.argc < 0'u8:
      return err(&"FrameDrawn: Argument count mismatch")

  when T is UseGraphicsFDParams:
    # argc [high]: 0; argc [low]: 0

    if msg.argc > 0'u8 or msg.argc < 0'u8:
      return err(&"UseGraphicsFD: Argument count mismatch")

    let dmaOpt = msg.fd(0)
    if !dmaOpt:
      return
        err(&"UseGraphicsFD: Missing non-optional file descriptor 'dma' at position 0")
    params.dma = &dmaOpt

  when T is TargetResizedParams:
    # argc [high]: 2; argc [low]: 2

    if msg.argc > 2'u8 or msg.argc < 2'u8:
      return err(&"TargetResized: Argument count mismatch")

    let renderSizeOpt = msg.argument(0, vmath.IVec2)
    if !renderSizeOpt:
      return err(
        "TargetResized: Missing non-optional argument 'renderSize' (IVec2) at position 0"
      )
    else:
      params.renderSize = &renderSizeOpt
    let strideOpt = msg.argument(1, uint32)
    if !strideOpt:
      return err(
        "TargetResized: Missing non-optional argument 'stride' (Uint32) at position 1"
      )
    else:
      params.stride = &strideOpt

  when T is SetPageTitleParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"SetPageTitle: Argument count mismatch")

    let titleOpt = msg.argument(0, string)
    if !titleOpt:
      return err(
        "SetPageTitle: Missing non-optional argument 'title' (String) at position 0"
      )
    else:
      params.title = &titleOpt

  when T is SetPCursorShapeParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"SetPCursorShape: Argument count mismatch")

    let predefOpt = msg.argument(0, uint8)
    if !predefOpt:
      return err(
        "SetPCursorShape: Missing non-optional argument 'predef' (Uint8) at position 0"
      )
    else:
      params.predef = &predefOpt

  when T is AlertMessageParams:
    # argc [high]: 1; argc [low]: 0

    if msg.argc > 1'u8 or msg.argc < 0'u8:
      return err(&"AlertMessage: Argument count mismatch")

    params.text = msg.argument(0, string)

  when T is UpdateNavigationParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"UpdateNavigation: Argument count mismatch")

    let locationOpt = msg.argument(0, url.URL)
    if !locationOpt:
      return err(
        "UpdateNavigation: Missing non-optional argument 'location' (URL) at position 0"
      )
    else:
      params.location = &locationOpt

  when T is UpdateStatusBarParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"UpdateStatusBar: Argument count mismatch")

    let textOpt = msg.argument(0, string)
    if !textOpt:
      return err(
        "UpdateStatusBar: Missing non-optional argument 'text' (String) at position 0"
      )
    else:
      params.text = &textOpt

  when T is ClipboardWriteTextParams:
    # argc [high]: 2; argc [low]: 2

    if msg.argc > 2'u8 or msg.argc < 2'u8:
      return err(&"ClipboardWriteText: Argument count mismatch")

    let textDataOpt = msg.argument(0, string)
    if !textDataOpt:
      return err(
        "ClipboardWriteText: Missing non-optional argument 'textData' (String) at position 0"
      )
    else:
      params.textData = &textDataOpt
    let promiseIdOpt = msg.argument(1, uint32)
    if !promiseIdOpt:
      return err(
        "ClipboardWriteText: Missing non-optional argument 'promiseId' (Uint32) at position 1"
      )
    else:
      params.promiseId = &promiseIdOpt

  when T is ClipboardReadTextParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"ClipboardReadText: Argument count mismatch")

    let promiseIdOpt = msg.argument(0, uint32)
    if !promiseIdOpt:
      return err(
        "ClipboardReadText: Missing non-optional argument 'promiseId' (Uint32) at position 0"
      )
    else:
      params.promiseId = &promiseIdOpt

  when T is CallEmbedBindingParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"CallEmbedBinding: Argument count mismatch")

    let routineOpt = msg.argument(0, string)
    if !routineOpt:
      return err(
        "CallEmbedBinding: Missing non-optional argument 'routine' (String) at position 0"
      )
    else:
      params.routine = &routineOpt

  when T is ProcessSpawnedParams:
    # argc [high]: 1; argc [low]: 1

    if msg.argc > 1'u8 or msg.argc < 1'u8:
      return err(&"ProcessSpawned: Argument count mismatch")

    let identifierOpt = msg.argument(0, uint64)
    if !identifierOpt:
      return err(
        "ProcessSpawned: Missing non-optional argument 'identifier' (Uint64) at position 0"
      )
    else:
      params.identifier = &identifierOpt
    let pidfdOpt = msg.fd(0)
    if !pidfdOpt:
      return err(
        &"ProcessSpawned: Missing non-optional file descriptor 'pidfd' at position 0"
      )
    params.pidfd = &pidfdOpt

  ok(ensureMove(params))
