## Wire format decoder routines
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[importutils, options]
import pkg/flatty, pkg/flatty/[binny, objvar]
import components/synapse/types

func initDecoder*(capacity: Natural = 4096): Decoder =
  privateAccess(types.Decoder)

  Decoder(buffer: newStringOfCap(capacity))

proc decode*[T](buffer: string, start, stop: uint32, typ: typedesc[T]): Option[T] =
  try:
    # TODO: some processing for SharedMemory
    some(fromFlatty(buffer[start .. stop], typ))
  except CatchableError:
    none(T)

proc decode*[O: SomeOrdinal](decoder: Decoder, op: typedesc[O]): Option[Message[O]] =
  privateAccess(types.Decoder)

  var msg: Message[O]
  msg.op = cast[O](decoder.buffer.readUint16(OpPosition))
  msg.argc = decoder.buffer.readUint8(ArgcPosition)
  msg.buffer = move(decoder.buffer)

  some(ensureMove(msg))

proc feed*(decoder: Decoder, buffer: sink EncodedBuffer) =
  privateAccess(types.Decoder)

  decoder.buffer = cast[string](buffer)

proc writeHandle*(decoder: Decoder, size: uint64): ptr char =
  privateAccess(types.Decoder)

  decoder.buffer.setLen(size)
  decoder.buffer[0].addr

func fd*(msg: Message, index: uint8): Option[int32] =
  if cast[uint8](msg.fds.len) < index:
    return none(int32)

  some(msg.fds[index])

proc argument*[T](msg: Message, index: uint8, typ: typedesc[T]): Option[T] =
  if msg.argc <= index:
    return none(T)

  let size = cast[uint32](msg.buffer.len) - 3
  var pos = 3'u32
  var arg: uint8

  while arg <= size and pos + 4 < size:
    let argSize = msg.buffer.readUint32(cast[int64](pos))
    if arg == index:
      return decode(msg.buffer, start = pos + 4, stop = pos + 4 + argSize - 1, typ)

    inc arg
    pos += 4 + argSize

  none(T)
