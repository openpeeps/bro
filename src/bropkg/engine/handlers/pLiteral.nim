# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

prefixHandle parseString:
  # parse strings
  result = newString(p.curr)
  walk p

prefixHandle parseInt:
  # parse integers
  if p.next.kind in tkUnits:
    let size = p.curr.value.parseInt
    walk p, 2
    return newSize(ast.newInt(size), toUnits(p.prev.kind))
  elif p.next.kind == tkMod and p.next.wsno == 0:
    let size = p.curr.value.parseInt
    walk p, 2
    return newSize(ast.newInt(size), PSIZE)
  result = ast.newInt(p.curr)
  walk p

prefixHandle parseBool:
  # parse boolean values
  result = newBool(p.curr)
  walk p

prefixHandle parseFloat:
  # parse float numbers
  if p.next.kind in tkUnits:
    let size = p.curr.value.parseFloat
    walk p, 2
    return newSize(newFloat(size), toUnits(p.prev.kind))
  elif p.next.kind == tkMod and p.next.wsno == 0:
    let size = p.curr.value.parseFloat
    walk p, 2
    return newSize(ast.newFloat(size), PSIZE)
  result = newFloat(p.curr)
  walk p

prefixHandle parseColor:
  # parse colors
  try:
    result = newColor(parseHtmlColor(p.curr.value))
    walk p
  except InvalidColor:
    error(colorsInvalidInput, p.curr, [p.curr.value])

prefixHandle parseNamedColor:
  # parse named colors
  if unlikely(p.isFnCall):
    p.curr.kind = tkIdentifier
    return p.pFunctionCall(excludeOnly, includeOnly)
  result = newColor(parseHtmlColor(p.curr.value))
  # result.colorType = ColorType.cNamed
  walk p

prefixHandle parseAccQuoted:
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
          if p.curr in tkTypedLiterals + {tkIdentifier}:
            p.curr.value.insert("$", 0)
            p.curr.kind = tkIdentifier # dirty fix
            # add result.accVal, indent("$bro" & $(hash(p.curr.value[1..^1])), tkSymbol.wsno)
            # let varNode = p.parseVarCall(tk, "$" & p.curr.value)
            let varNode = p.pIdentCall()
            if likely(varNode != nil):
              # varNode.callIdent = "$" & varNode.callIdent 
              add result.accVars, varNode
            else: return nil
          else:
            let prefixInfixNode = p.getPrefixOrInfix(includeOnly = {tkInteger, tkFloat, tkVarCall, tkFnCall, tkIdentifier})
            # if likely(prefixInfixNode != nil):
            #   case prefixInfixNode.nt
            #   of ntInt, ntBool:
            #     add result.accVal, indent("$bro" & $(hash(p.curr.value)), tkSymbol.wsno)
            #   of ntInfixMathExpr, ntInfixExpr:
            #     add result.accVal, indent("$bro" & $(hash(prefixInfixNode)), tkSymbol.wsno)
            #   else: discard
            #   add result.accVars, prefixInfixNode
            # else: return nil
        walk p # tkRC
    else:
      add result.accVal, indent(p.curr.value, p.curr.wsno)
      walk p
  walk p # tkAccQuoted