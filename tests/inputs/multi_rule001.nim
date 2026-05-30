import components/style/parser
import pretty

let v = newParser(
  newParserInput(
    """
a, b, c {
  x: y;
}
"""
  )
)

print v.parseStylesheet()
