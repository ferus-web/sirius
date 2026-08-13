## Wire format encoder. This just uses flatty.
##
## Copyright (C) 2026 Trayambak Rai (xtrayambak@disroot.org)
import std/[importutils]
import pkg/[flatty, shakar], pkg/flatty/[binny, objvar]
import components/synapse/types

func toFlatty*[T: SomeOrdinal](s: var string, x: set[T]) =
  toFlatty(
    s,
    (
      when sizeof(T) == 1: cast[uint8](x)
      elif sizeof(T) == 2: cast[uint16](x)
      elif sizeof(T) == 4: cast[uint32](x)
      elif sizeof(T) == 8: cast[uint64](x)
      else: unreachable
    ),
  )

func initEncoder*(capacity: Natural = 4096): Encoder =
  privateAccess(types.Encoder)
  Encoder(buffer: newStringOfCap(capacity), argc: 0'u8)

proc encode*[O: SomeOrdinal](encoder: Encoder, op: O) =
  static:
    assert(sizeof(O) == 2, "IPC opcodes must be 2 bytes big")

  privateAccess(types.Encoder)

  encoder.buffer.setLen(3)
  encoder.argc = 0'u8
  encoder.buffer.writeUint16(OpPosition, cast[uint16](op))
  encoder.fds.reset()

proc push*[T](encoder: Encoder, value: T) =
  privateAccess(types.Encoder)

  when value is FileDescriptor:
    encoder.fds &= cast[int32](value)
    return

  inc encoder.argc
  encoder.buffer.writeUint8(ArgcPosition, encoder.argc)

  encoder.buffer.setLen(encoder.buffer.len + 4)

  let sizePos = encoder.buffer.len - 4
  encoder.buffer.writeUint32(sizePos, 0'u32)

  let oldSize = encoder.buffer.len

  toFlatty(encoder.buffer, value)

  let currSize = encoder.buffer.len
  assert(currSize > oldSize)

  let objSize = currSize - oldSize
  assert(
    objSize < cast[int64](uint32.high), "encoder: Invariant: object size exceeds 4GB!?"
  ) # god forbid this ever happens

  encoder.buffer.writeUint32(sizePos, cast[uint32](objSize))

func finalize*(encoder: Encoder): EncodedBuffer =
  privateAccess(types.Encoder)
  cast[EncodedBuffer](encoder.buffer)
