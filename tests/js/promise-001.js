const promise = new Promise(function(resolve, reject) {
  console.log("executor called");
  console.log("resolve =", resolve)
  console.log("reject =", reject)

  reject("nyaa");
  resolve("hej");
});

console.log("Promise.prototype.then =", promise.then);
promise.then(
  function(val) {
    console.log("fulfilled; val =", val);
  },
  function(val) {
    console.log("rejected; val =", val);
  }
)
