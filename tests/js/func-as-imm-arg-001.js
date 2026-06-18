/* function greeter() {
  console.log("Guten Morgen, guten Morgen");
  console.log("Guten Morgen, Sonnenschein");
  console.log("Diese Nacht blieb vir verborgen");
} */

function eater(x) {
  console.log(x)
  x()
}

eater(function() {
  console.log("Guten Morgen, guten Morgen");
  console.log("Guten Morgen, Sonnenschein");
  console.log("Diese Nacht blieb vir verborgen");
})
