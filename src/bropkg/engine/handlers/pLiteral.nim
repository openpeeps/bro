# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

newPrefixProc "parseString":
  # parse strings
  result = newString(p.curr.value)
  walk p

newPrefixProc "parseInt":
  # parse integers
  if p.next.kind in tkUnits:
    walk p
    return newSize(parseInt(p.prev.value), toUnits(p.curr.kind))
  result = newInt(p.curr.value)
  walk p

newPrefixProc "parseBool":
  # parse boolean values
  result = newBool(p.curr.value)
  walk p

newPrefixProc "parseFloat":
  # parse float numbers
  result = newFloat(p.curr.value)
  walk p

newPrefixProc "parseColor":
  # parse colors
  result = newColor(p.curr.value)
  result.colorType = ColorType.cHex
  walk p

newPrefixProc "parseNamedColor":
  # parse named colors
  result = newColor(p.curr.value)
  result.colorType = ColorType.cNamed
  walk p

newPrefixProc "parseRGBColor":
  # parse RGB colors
  discard

newPrefixProc "parseRGBAColor":
  # parse RGBA colors
  discard

newPrefixProc "parseHSLColor":
  # parse HSL colors
  discard

newPrefixProc "parseHSLAColor":
  # parse HSLA colors
  discard

newPrefixProc "parseAccQuoted":
  # parse string/var concat using backticks
  result = newAccQuoted(p.curr.value)
  if p.curr.attr.len != 0:
    let acc = p.curr
    for varName in acc.attr:
      let varNode = p.parseVarCall(acc, "$" & varName, scope)
      if unlikely(varNode == nil):
        return nil
      add result.accVars, varNode
  else: walk p