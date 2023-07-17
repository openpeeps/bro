newPrefixProc "parseString":
  result = newString(p.curr.value)
  walk p

newPrefixProc "parseInt":
  result = newInt(p.curr.value)
  walk p

newPrefixProc "parseBool":
  result = newBool(p.curr.value)
  walk p

newPrefixProc "parseFloat":
  result = newFloat(p.curr.value)
  walk p

newPrefixProc "parseColor":
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