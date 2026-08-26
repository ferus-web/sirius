## Small bug testcase when encoding booleans
import std/unittest
import components/synapse/[decoder, encoder, types]
import pkg/flatty/[binny, hexprint], pkg/shakar

type TestOpFoo {.pure, size: sizeof(uint16).} = enum
  One
  Two
  Three
  Four

test "bug when attempting to decode booleans (or any 1-byte argument)":
  let enc = initEncoder()
  enc.encode(TestOpFoo.One)
  enc.push("hello")
  enc.push("hi")
  enc.push(true)

  let finalEnc = enc.finalize()

  # echo hexPrint(cast[string](finalEnc))

  let dec = initDecoder()
  dec.feed(finalEnc)

  let msg = &dec.decode(TestOpFoo)
  check &msg.argument(0, string) == "hello"
  check &msg.argument(1, string) == "hi"
  check &msg.argument(2, bool) == true
