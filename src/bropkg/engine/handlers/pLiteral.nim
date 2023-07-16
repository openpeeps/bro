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