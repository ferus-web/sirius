import std/unittest
import components/synapse/[decoder, encoder, types]
import pkg/flatty/[binny, hexprint], pkg/shakar

type
  TestOpFoo {.pure, size: sizeof(uint16).} = enum
    Ek
    Do
    Tin
    Char

  TestOpBar {.pure, size: sizeof(uint16).} = enum
    One
    Two
    Three
    Four

  DoPayload = object
    age: int8
    name: string

let enc = initEncoder()
enc.encode(TestOpFoo.Ek)
enc.push("hello there :3")
enc.push(DoPayload(age: 28, name: "John"))
enc.push(DoPayload(age: 27, name: "Jane"))

let finalEnc = enc.finalize()

echo hexPrint(cast[string](finalEnc))

let dec = initDecoder()
dec.feed(finalEnc)

let msg = &dec.decode(TestOpFoo)
echo msg.argument(0, string)
echo msg.argument(1, DoPayload)
echo msg.argument(2, DoPayload)
