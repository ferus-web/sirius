var x = new Object; // TODO: Make {} just turn into a constructor call for Object
x.hello = "hallo";

var y = new Object;
y.result = "Field resolution seems to have worked!"
x.a = y;

console.log(x.a.result)
