# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

newPrefixProc "parseReturnCommand":
  ## Parse a `return` command
  let tk = p.curr
  walk p
  let node = p.getPrefixOrInfix(includeOnly = {tkVarCall, tkString,
      tkAccQuoted, tkInteger, tkFloat, tkBool, tkIdentifier, tkLC, tkLB})
  if likely(node != nil):
    case node.nt
    of ntCallFunction:
      if node.callReturnType == ntVoid:
        errorWithArgs(fnReturnVoid, tk, [node.stackIdentName])
    else: discard
    if node != nil:
      result = newReturn(node)

proc parseAccessor(p: var Parser, varNode: Node, tk: TokenTuple): Node =
  # Parse accessor storage. $[0][1]["x"][$y]
  while p.curr is tkLB and p.curr.line == tk.line:
    if result == nil:
      case p.next.kind
      of tkInteger:
        result = p.parseArrayAccessor(varNode)
      of tkString:
        result = p.parseObjectAccessor(varNode)
      of tkVarCall:
        result = p.parseCallAccessor(varNode)
      of tkIdentifier:
        walk p
        if p.isFnCall():
          echo "todo"
        else: return
      else: return # error
    else:
      case p.next.kind
      of tkInteger:
        result = p.parseArrayAccessor(result)
      of tkString:
        result = p.parseObjectAccessor(result)
      of tkVarCall:
        result = p.parseCallAccessor(result)
      of tkIdentifier:
        walk p
        if p.isFnCall():
          echo "todo"
        else: return nil
      else: return nil # error

newPrefixProc "parseCallCommand":
  # Parse variable calls
  let tk = p.curr
  result = ast.newCall(tk)
  walk p
  if p.curr is tkLB and p.curr.line == tk.line:
    var accessorNode = p.parseAccessor(newVariable(tk), tk)
    if likely(accessorNode != nil):
      result.callNode = accessorNode
    else: error(invalidAccessorStorage, tk)
  elif p.curr is tkDotExpr:
    walk p
    if likely(p.isFnCall()):
      var fnCallNode = p.parseCallFnCommand()
      fnCallNode.stackArgs.insert(result, 0)
      fnCallNode.stackIdent = fnCallNode.stackIdentName & "|" & $(fnCallNode.stackArgs.len)
      return fnCallNode

newPrefixProc "parseEchoCommand":
  # Parse a new `echo` command
  let tk = p.curr
  walk p
  # if p.curr.kind == tkIdentifier and p.next isnot tkLPAR:
  #   if scope.len > 0:
  #     if scope[^1].hasKey(p.curr.value):
  #       return newEcho(scope[^1][p.curr.value], tk)
  #   if p.program.getStack.hasKey(p.curr.value):
  #     walk p
  #     return newEcho(newInfo(p.program.getStack()[p.prev.value]), tk)
  let node = p.getPrefixOrInfix(isFunctionWrap = isFunctionWrap,
              excludeOnly = {tkEcho, tkReturn, tkVar, tkConst, tkFnDef})
  if node != nil:
    # case node.nt
    # of ntCallFunction:
    #   if node.callReturnType == ntVoid:
    #     errorWithArgs(fnReturnVoid, tk, [node.stackIdentName])
    # else: discard
    return newEcho(node, tk)

newPrefixProc "parseAssert":
  # Parse a new `assert` command
  let tk = p.curr
  walk p
  let exp = p.getPrefixOrInfix(isFunctionWrap = isFunctionWrap,
              includeOnly = {tkInteger, tkFloat, tkBool, tkString,
                            tkVarCall, tkIdentifier, tkFnCall} + tkNamedColors)
  if likely(exp != nil):
    case exp.nt:
    of ntInfix:
      result = newAssert(exp, tk)
    of ntCall:
      if exp.getNodeType in {ntBool, ntInt, ntFloat, ntString}:
        result = newAssert(exp, tk)
    else:
      errorWithArgs(assertionInvalid, tk, [$exp.nt])