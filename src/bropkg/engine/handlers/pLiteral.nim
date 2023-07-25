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
  walk p

newPrefixProc "parseAccQuoted":
  # parse variable calls
  if p.curr.attr.len != 0:
    result = newAccQuoted(p.curr.value)
    for varName in p.curr.attr:
      let varNode = p.parseVarCall(p.curr, "$" & varName, scope)
      if unlikely(varNode == nil):
        return nil
      add result.accVars, varNode
  walk p