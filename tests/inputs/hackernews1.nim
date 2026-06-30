import components/style/parser
import components/aux/pretty

let parsing = newParser(newParserInput(readFile "tests/inputs/css/hackernews.css"))
let ss = parsing.parseStylesheet()

print ss
