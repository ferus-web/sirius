const promise = new Promise(function(resolve, reject) {
  console.log("executor called");
  console.log(resolve)
  console.log(reject)
});
