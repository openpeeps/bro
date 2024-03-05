import ./ast
from std/strutils import join

proc fmt(fn, v: string): string =
  fn & "(" & v & ")"

proc url*(x: string): string =
  fmt("url", "\"" & x & "\"")

proc abs*(x: int): string =
  fmt("abs", $x)

proc acos*(x: int): int = x
proc asin*(x: int): int = x
proc atan*(x: int): int = x
proc atan*(x: float): float = x

proc fitContent*(x: Node): string =
  var y: string
  case x.sizeVal.nt
  of ntInt:
    y = $(x.sizeVal.iVal)
  of ntFloat:
    y = $(x.sizeVal.fVal)
  else: discard
  fmt("fit-content", $y & $x.sizeUnit)

proc conicGradient*(a, b, c: Color): string =
  var x = [a.toHtmlHex, b.toHtmlHex, c.toHtmlHex]
  fmt("conic-gradient", x.join(", "))