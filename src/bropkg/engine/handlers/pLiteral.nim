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
  let tk = p.curr
  walk p
  result = Node(nt: ntAccQuoted)
  while p.curr isnot tkAccQuoted:
    case p.curr.kind
    of tkEOF: return nil
    of tkVarSymbol:
      let tkSymbol = p.curr
      if p.next is tkLC:
        walk p, 2
        while p.curr isnot tkRC:
          if unlikely(p.curr is tkEOF): return nil
          add result.accVal, indent("$bro" & $(hash(p.curr.value)), tkSymbol.wsno)
          if p.curr is tkIdentifier:
            let varNode = p.parseVarCall(tk, "$" & p.curr.value, scope)
            if likely(varNode != nil):
              add result.accVars, varNode
            else: return nil
        walk p # tkRC
    else:
      add result.accVal, indent(p.curr.value, p.curr.wsno)
      walk p
  walk p # tkAccQuoted