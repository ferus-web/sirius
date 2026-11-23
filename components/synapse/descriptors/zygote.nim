## *Generated automatically by scanner. Do not edit!*
## **Source**: ipc/zygote.ipdl
import std/options
import components/synapse/[encoder, types]
import components/synapse/client
import pkg/[results, shakar]

type ZygoteOp* {.pure, size: sizeof(uint16).} = enum
  Spawn = 0

# Sender API

proc spawn*(ctx: Client, kind: uint8, channel: FileDescriptor, identifier: uint64) =
  ctx.encoder.encode(ZygoteOp.Spawn)
  ctx.encoder.push(kind)
  ctx.encoder.push(channel)
  ctx.encoder.push(identifier)
  ctx.send()

# Recipient API
type SpawnParams* = object
  kind*: uint8
  channel*: FileDescriptor
  identifier*: uint64

proc params*[T: object](msg: Message[ZygoteOp], _: typedesc[T]): Result[T, string] =
  var params: T

  when T is SpawnParams:
    # argc [high]: 2; argc [low]: 2

    if msg.argc > 2'u8 or msg.argc < 2'u8:
      return err(&"Spawn: Argument count mismatch")

    let kindOpt = msg.argument(0, uint8)
    if !kindOpt:
      return err("Spawn: Missing non-optional argument 'kind' (Uint8) at position 0")
    else:
      params.kind = &kindOpt
    let channelOpt = msg.fd(0)
    if !channelOpt:
      return err(&"Spawn: Missing non-optional file descriptor 'channel' at position 0")
    params.channel = &channelOpt
    let identifierOpt = msg.argument(2, uint64)
    if !identifierOpt:
      return
        err("Spawn: Missing non-optional argument 'identifier' (Uint64) at position 2")
    else:
      params.identifier = &identifierOpt

  ok(ensureMove(params))
