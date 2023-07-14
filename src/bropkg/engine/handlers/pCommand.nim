newPrefixProc "parseEchoCommand":
  # Parse an `echo` command. Echo can print literals, functions and infix operations
  let tk = p.curr
  walk p
  if p.curr.kind == tkIdentifier and p.next isnot tkLPAR:
    if scope != nil:
      if scope.hasKey(p.curr.value):
        return newEcho(scope[p.curr.value], tk)
    if p.program.stack.hasKey(p.curr.value):
      walk p
      return newEcho(newInfo(p.program.stack[p.prev.value]), tk)
  let node = p.getPrefixOrInfix(excludeOnly = {tkEcho, tkReturn, tkVarDef, tkFnDef}, scope = scope)
  if node != nil:
    case node.nt
    of ntCallStack:
      if node.stackReturnType == ntVoid:
        errorWithArgs(fnReturnVoid, tk, [node.stackIdentName])
    else: discard
    return newEcho(node, tk)

newPrefixProc "parseReturnCommand":
  let tk = p.curr
  walk p
  let node = p.getPrefixOrInfix(excludeOnly = {tkEcho, tkReturn, tkVarDef, tkFnDef}, scope = scope)
  if node != nil:
    case node.nt
    of ntCallStack:
      if node.stackReturnType == ntVoid:
        errorWithArgs(fnReturnVoid, tk, [node.stackIdentName])
    else: discard
    if node != nil:
      result = newReturn(node)

newPrefixProc "parseCallCommand":
  if scope != nil:
    if scope.hasKey(p.curr.value):
      walk p
      return newCall(p.prev.value, scope[p.prev.value])
  if likely(p.program.stack.hasKey(p.curr.value)):
    let gVal = p.program.stack[p.curr.value]
    case gVal.nt:
    of ntVarValue: 
      gVal.varUsed = true
    else: discard
    walk p
    return newCall(p.prev.value, gVal)
  errorWithArgs(UndeclaredVariable, p.curr, [p.curr.value])
