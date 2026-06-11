import components/style/parser
import pretty

let parsing = newParser(newParserInput(readFile "tests/inputs/css/hackernews.css"))
let ss = parsing.parseStylesheet()

print ss
