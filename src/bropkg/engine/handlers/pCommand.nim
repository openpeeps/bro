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

proc parseVarCall(p: var Parser, tk: TokenTuple, varName: string, scope: ScopeTable, skipWalk = true): Node =
  # Parse given identifier and return it as `ntCall` node
  if scope != nil:
    if scope.hasKey(varName):
      return newCall(varName, scope[varName])
  if likely(p.program.stack.hasKey(varName)):
    let gVal = p.program.stack[varName]
    case gVal.nt:
    of ntVarValue: 
      gVal.varUsed = true
    else: discard
    if not skipWalk: walk p
    return newCall(varName, gVal)
  errorWithArgs(UndeclaredVariable, tk, [varName])

newPrefixProc "parseCallCommand":
  # Parse variable calls
  result = p.parseVarCall(p.curr, p.curr.value, scope, false)