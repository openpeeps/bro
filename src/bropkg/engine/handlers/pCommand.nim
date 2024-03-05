# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

prefixHandle parseReturnCommand:
  ## Parse a `return` command
  let tk = p.curr
  walk p
  let node = p.getPrefixOrInfix(includeOnly = {tkVarCall, tkString,
      tkAccQuoted, tkInteger, tkFloat, tkBool, tkIdentifier, tkLC, tkLB})
  if likely(node != nil):
    case node.nt
    of ntCallFunction:
      if node.fnCallReturnType == ntVoid:
        errorWithArgs(fnReturnVoid, tk, [node.fnCallIdentName])
    else: discard
    if node != nil:
      result = newReturn(node)

proc parseAccessor(p: var Parser, varNode: Node, tk: TokenTuple): Node =
  # Parse accessor storage. $[0][1]["x"][$y]
  while p.curr is tkLB and p.curr.line == tk.line:
    notnil result:
      case p.next.kind
      of tkInteger:
        result = p.parseArrayAccessor(result)
      of tkString:
        result = p.parseObjectAccessor(result)
      # of tkVarCall:
      #   result = p.parseCallAccessor(result)
      of tkIdentifier:
        walk p
        if p.isFnCall():
          echo "todo"
        else: return nil
      else: return nil # error
    do:
      case p.next.kind
      of tkInteger:
        result = p.parseArrayAccessor(varNode)
      of tkString:
        result = p.parseObjectAccessor(varNode)
      # of tkVarCall:
        # result = p.parseCallAccessor(varNode)
      of tkIdentifier:
        walk p
        if p.isFnCall():
          echo "todo"
        else: return
      else: return # error

prefixHandle pIdentCall:
  # parse ident calls
  let tk = p.curr
  result = ast.newCall(tk)
  walk p
  if p.curr.line == result.meta[0]:
    case p.curr.kind
    of tkLB:
      result = p.parseBracketExpr(result)
      notnil result:
        discard
    of tkDot:
      result = p.parseDotExpr(result)
      notnil result:
        discard
    else: discard # todo

prefixHandle parseEchoCommand:
  # Parse a new `echo` command
  let tk = p.curr
  walk p
  let node = p.getPrefixOrInfix(isFunctionWrap = isFunctionWrap,
              excludeOnly = {tkEcho, tkReturn, tkVar, tkConst, tkFnDef})
  notnil node:
    result = newEcho(node, tk)

# prefixHandle parseAssert:
#   # Parse a new `assert` command
#   let tk = p.curr
#   walk p
#   let exp = p.getPrefixOrInfix(isFunctionWrap = isFunctionWrap,
#               includeOnly = {tkInteger, tkFloat, tkBool, tkString,
#                             tkVarCall, tkIdentifier, tkFnCall} + tkNamedColors)
#   if likely(exp != nil):
#     case exp.nt:
#     of ntInfixExpr:
#       result = newAssert(exp, tk)
#     of ntIdent:
#       if exp.getNodeType in {ntBool, ntInt, ntFloat, ntString}:
#         result = newAssert(exp, tk)
#     else:
#       errorWithArgs(assertionInvalid, tk, [$exp.nt])
