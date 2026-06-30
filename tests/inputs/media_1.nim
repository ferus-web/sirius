import components/style/parser
import components/aux/pretty

let parsing = newParser(newParserInput(readFile("tests/inputs/css/media-1.css")))
let ss = parsing.parseStylesheet()

print ss
