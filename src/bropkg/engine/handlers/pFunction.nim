newPrefixProc "parseFn":
  let
    fn = p.curr
    fnName = p.next
    scope = if scope == nil: ScopeTable() else: scope
  walk p # `fn`
  var fnNode = newFunction(fnName)
  walk p # function identifier
  var types: seq[NodeType]
  if p.curr.kind == tkLPAR and p.curr.line == fn.line:
    # parse function parameters
    walk p # (
    while p.next.kind == tkColon and p.curr.kind == tkIdentifier:
      walk p
      let pName = p.prev
      case p.curr.kind
      of tkColon:
        if likely(fnNode.fnParams.hasKey(pName.value) == false):
          walk p
          case p.curr.kind:
          of tkTypedLiterals:
            # Set type for current argument
            let nTyped = p.getLiteralType()
            fnNode.fnParams["$" & pName.value] = ("$" & pName.value, nTyped, nil)
            scope["$" & pName.value] = nil
            types.add(nTyped)
            walk p
            # todo support default assignments
          else: return # UnexpectedToken
        else: errorWithArgs(fnAttemptRedefineIdent, pName, [pName.value])
      of tkAssign:
        # Set type and value from given assignment 
        discard # todo
      else: break # UnexpectedToken
      if p.curr.kind == tkComma:
        walk p
      else: break
  fnNode.fnIdent = identify(fnNode.fnName, types)
  if p.curr.kind == tkRPAR:
    walk p
    # parse function return type
    if p.curr.kind == tkColon:
      walk p
      fnNode.fnReturnType = p.getLiteralType()
      if fnNode.fnReturnType != ntVoid:
        walk p
      else: error(fnInvalidReturn, p.curr)

    # parse function body
    if p.curr.kind == tkAssign:
      if fn.line == p.curr.line:
        walk p
        let stmtNode =
          p.parseStatement((fn, fnNode), scope = scope,
            excludeOnly = {tkImport, tkUse},
            returnType = fnNode.fnReturnType, isFunctionWrap = true)
        if stmtNode != nil:
          fnNode.fnBody = stmtNode
          stmtNode.cleanup # out of scope
          if p.lastParent != nil:
            case p.lastParent.nt
            of ntFunction:
              # check for name collisions. main function <> closures
              if p.lastParent.fnName != fnNode.fnName:
                fnNode.fnClosure = true
              scope.localScope(fnNode) # add closure to local scope
            of ntCondStmt, ntCaseStmt, ntForStmt:
              scope.localScope(fnNode) # add blocks to local scope
            else: discard
          else:
            if isFunctionWrap:
              scope.localScope(fnNode)
            else:
              p.globalScope(fnNode) # add in glboal scope
      result = fnNode

newPrefixProc "parseCallFnCommand":
  # Parse function calls with or without arguments,
  # looking for the following pattern: `fn myfn($a: string, $b: Int = 0): string =`
  let ident = p.curr
  walk p, 2 # (
  var
    args: seq[Node]
    types: seq[NodeType]
  while p.curr isnot tkRPAR:
    let arg = p.getPrefixOrInfix(scope, excludeOnly = {tkEcho, tkReturn, tkVarDef, tkFnDef})
    if arg != nil:
      add args, arg
      add types, arg.nt
    else: return
    if p.curr is tkComma:
      walk p
  walk p # )
  var fn: Node
  let fnIdentName = identify(ident.value, types)
  if p.program.stack.hasKey(fnIdentName):
    fn = p.program.stack[fnIdentName]
  elif scope != nil:
    if scope.hasKey(fnIdentName):
      fn = scope[fnIdentName]
    else: errorWithArgs(fnUndeclared, ident, [ident.value])
  else: errorWithArgs(fnUndeclared, ident, [ident.value])
  if likely(args.len == fn.fnParams.len):
    var i = 0  
    for pKey, pDef in fn.fnParams:
      try:
        if likely(args[i].getNodeType == pDef[1]):
          use(args[i])
        else:
          errorWithArgs(fnMismatchParam, ident, [pDef[0], $(args[i].getNodeType), $(pDef[1])])
      except IndexDefect:
        error(fnExtraArg, ident)
      inc i 
    use fn
    result = newFnCall(fn, args, fnIdentName, ident.value)
  else:
    errorWithArgs(fnExtraArg, ident, [ident.value, $len(fn.fnParams), $len(args)])
