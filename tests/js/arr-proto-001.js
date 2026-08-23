var arr = new Array(1)
arr.push(32)
arr.push(3.14)
arr.push(3.15)

console.log(arr.pop()) // 3.15;
console.log(arr.indexOf(3.15)); // -1
console.log(arr.indexOf(3.14)); // 2
console.log(arr.indexOf(undefined)); // 0
