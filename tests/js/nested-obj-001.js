var x = new Object; // TODO: Make {} just turn into a constructor call for Object
x.hello = "hallo";

var y = new Object;
x.a = y;

console.log("x.hello =>", x.hello)
console.log("x.a =>", x.a)
console.log("x.z =>", x.z) 
