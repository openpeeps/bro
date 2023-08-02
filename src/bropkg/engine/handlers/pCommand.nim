# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

newPrefixProc "parseReturnCommand":
  let tk = p.curr
  walk p
  let node = p.getPrefixOrInfix(includeOnly = {tkVarCall, tkString, tkInteger, tkFloat, tkBool, tkIdentifier}, scope = scope)
  if node != nil:
    case node.nt
    of ntCallStack:
      if node.stackReturnType == ntVoid:
        errorWithArgs(fnReturnVoid, tk, [node.stackIdentName])
    else: discard
    if node != nil:
      result = newReturn(node)

proc parseAccessor(p: var Parser, varNode: Node, scope: var seq[ScopeTable], tk: TokenTuple): Node =
  while p.curr is tkLB and p.curr.line == tk.line:
    if p.next notin {tkInteger, tkString}:
      errorWithArgs(unexpectedToken, p.next, [p.next.value])
    if result == nil:
      if p.next is tkInteger:
        result = p.parseArrayAccessor(varNode, scope)
      elif p.next is tkString:
        result = p.parseObjectAccessor(varNode, scope)
      else: result = nil # error
    else:
      if p.next is tkInteger:
        result = p.parseArrayAccessor(result, scope)
      elif p.next is tkString:
        result = p.parseObjectAccessor(result, scope)
      else: result = nil # error

proc parseVarCall(p: var Parser, tk: TokenTuple, varName: string, scope: var seq[ScopeTable]): Node =
  # Parse a variable call. This handler can parse basic calls 
  let
    varName = if likely(varName.len == 0): p.curr.value else: varName
    currentScope = p.getScope(varName, scope)
    hashedVarName = hash(varName & $(currentScope.index))
  walk p # tkVariable
  if currentScope.st != nil:
    var callNode = memoized(p.mVar, hashedVarName)
    if likely(callNode == nil):
      var varNode = currentScope.st[varName]
      if p.curr is tkLB and p.curr.line == tk.line:
        var accessorNode: Node
        accessorNode = p.parseAccessor(varNode, scope, tk)
        callNode = newCall(varName, accessorNode)
      else:
        callNode = newCall(varName, varNode)
        p.mVar.memoize(hashedVarName, callNode)
      use(varNode)
    return callNode
  errorWithArgs(UndeclaredVariable, tk, [varName])

newPrefixProc "parseCallCommand":
  # Parse variable calls
  p.parseVarCall(p.curr, "", scope)

newPrefixProc "parseEchoCommand":
  # Parse an `echo` command. Echo can print literals, functions and infix operations
  let tk = p.curr
  walk p
  if p.curr.kind == tkIdentifier and p.next isnot tkLPAR:
    if scope.len > 0:
      if scope[^1].hasKey(p.curr.value):
        return newEcho(scope[^1][p.curr.value], tk)
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