function callMe(x) {
  // HACK: Why does comparing the array in one shot fail? The exception is equally absurd.
  assert.sameValue(1, x[0], "x[0] == 1");
  assert.sameValue(2, x[1], "x[1] == 2");
  assert.sameValue(3, x[2], "x[2] == 3");
}

callMe([1, 2, 3])
