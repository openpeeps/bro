proc parseEchoCommand(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  # Parse an `echo` command. Echo can print literals, functions and infix operations
  let tk = p.curr
  walk p  
  if p.curr.kind == tkIdentifier and p.next isnot tkLPAR:
    if scope != nil:
      if scope.hasKey(p.curr.value):
        echo "scope" # todo
    if p.program.stack.hasKey(p.curr.value):
      walk p
      return newEcho(newInfo(p.program.stack[p.prev.value]), tk)
  let node = p.getPrefixOrInfix(excludeOnly = {tkEcho, tkReturn, tkVarDef, tkFnDef}, scope = scope)
  if node != nil:
    case node.nt
    of ntCallStack:
      if node.callStackReturnType == ntVoid:
        errorWithArgs(functionReturnVoid, tk, [node.callStackIdent])
    else: discard
    return newEcho(node, tk)

proc parseReturnCommand(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  let tk = p.curr
  walk p
  let node = p.getPrefixOrInfix(excludeOnly = {tkEcho, tkReturn, tkVarDef, tkFnDef}, scope = scope)
  if node != nil:
    case node.nt
    of ntCallStack:
      if node.callStackReturnType == ntVoid:
        errorWithArgs(functionReturnVoid, tk, [node.callStackIdent])
    else: discard
    if node != nil:
      result = newReturn(node)

proc parseCallCommand(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  if likely(p.program.stack.hasKey(p.curr.value)):
    let gVal = p.program.stack[p.curr.value]
    case gVal.nt:
    of ntVarValue: 
      gVal.varUsed = true
    else: discard
    result = newCall(p.curr.value, gVal)
    walk p
  else:
    if scope != nil:
      if scope.hasKey(p.curr.value):
        walk p
        return newCall(p.prev.value, scope[p.prev.value])
    errorWithArgs(UndeclaredVariable, p.curr, [p.curr.value])