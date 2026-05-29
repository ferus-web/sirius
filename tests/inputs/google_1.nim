import components/style/parser
import pretty

let parsing =
  newParser(newParserInput(readFile("tests/inputs/css/google-1.beautified.css")))
let ss = parsing.parseStylesheet()

print ss
