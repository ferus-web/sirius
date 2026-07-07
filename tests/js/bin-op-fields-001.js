var x = new Object;
x.thing = 32;

let v = 32 + x.thing;
assert.sameValue(v, 64, "can access fields in arith expressions")
