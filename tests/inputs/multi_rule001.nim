import components/style/parser
import components/aux/pretty

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
