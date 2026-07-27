# JavaScript TODOs
- [ ] Improve the frontend. Seriously.
  * [ ] Object construction via braces (`{ x: "y" }` and so on)
  * [ ] Complex expressions (e.g mixing function calls and literals in arithmetic expressions)
  * [ ] Default parameter parsing in functions
  * [ ] Array index field access (e.g `navigator["oscpu"]` instead of `navigator.oscpu`)
  * [ ] Complex error throwing (not just atoms)
  * [ ] Complex and nested ternaries
- [ ] Code generation for `ListIterator` (currently, we simply parse and ignore it, but we do generate *some* code for generating the list itself)
- [ ] Stop using GNU MP for bigints, possibly [nim-lang/bigints](https://github.com/nim-lang/bigints) or whatever constantine does?
- [X] On *NIXes, we can probably seed Bali's RNG state with the bytes in the auxiliary vector.
