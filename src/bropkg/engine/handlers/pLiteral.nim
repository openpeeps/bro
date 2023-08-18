# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

newPrefixProc "parseString":
  # parse strings
  result = newString(p.curr)
  walk p

newPrefixProc "parseInt":
  # parse integers
  if p.next.kind in tkUnits:
    let size = p.curr.value.parseInt
    walk p, 2
    return newSize(newInt(size), toUnits(p.prev.kind))
  result = newInt(p.curr)
  walk p

newPrefixProc "parseBool":
  # parse boolean values
  result = newBool(p.curr)
  walk p

newPrefixProc "parseFloat":
  # parse float numbers
  if p.next.kind in tkUnits:
    let size = p.curr.value.parseFloat
    walk p, 2
    return newSize(newFloat(size), toUnits(p.prev.kind))
  result = newFloat(p.curr)
  walk p

newPrefixProc "parseColor":
  # parse colors
  result = newColor(p.curr.value)
  result.colorType = ColorType.cHex
  walk p

newPrefixProc "parseNamedColor":
  # parse named colors
  if unlikely(p.isFnCall):
    p.curr.kind = tkIdentifier
    return p.parseCallFnCommand(excludeOnly, includeOnly)
  result = newColor(p.curr.value)
  result.colorType = ColorType.cNamed
  walk p

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
          if p.curr in tkTypedLiterals + {tkIdentifier}:
            p.curr.kind = tkIdentifier # dirty fix
            add result.accVal, indent("$bro" & $(hash(p.curr.value)), tkSymbol.wsno)
            # let varNode = p.parseVarCall(tk, "$" & p.curr.value)
            let varNode = p.parseCallCommand()
            if likely(varNode != nil):
              add result.accVars, varNode
            else: return nil
          else:
            let prefixInfixNode = p.getPrefixOrInfix(includeOnly = {tkInteger, tkFloat, tkVarCall, tkFnCall, tkIdentifier})
            if likely(prefixInfixNode != nil):
              case prefixInfixNode.nt
              of ntInt, ntBool:
                add result.accVal, indent("$bro" & $(hash(p.curr.value)), tkSymbol.wsno)
              of ntMathStmt, ntInfix:
                add result.accVal, indent("$bro" & $(hash(prefixInfixNode)), tkSymbol.wsno)
              else: discard
              add result.accVars, prefixInfixNode
            else: return nil
        walk p # tkRC
    else:
      add result.accVal, indent(p.curr.value, p.curr.wsno)
      walk p
  walk p # tkAccQuoted