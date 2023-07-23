newPrefixProc "parseFn":
  # Parse function definition using `fn` identifier.
  # Function definition is inspired from Nim language:
  #```bass
  # fn hello(name: string): string =
  #   return $name
  #```
  let
    fn = p.curr
    fnName = p.next
    fnScope = ScopeTable()
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
            fnScope["$" & pName.value] = newVariable("$" & pName.value, newValue(Node(nt: nTyped)), pName)
            fnScope["$" & pName.value].varImmutable = true
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
  if unlikely(p.inScope(fnNode.fnIdent, scope)):
    errorWithArgs(fnOverload, fnName, [fnName.value])
  if p.curr.kind == tkRPAR:
    walk p
    # parse function return type
    if p.curr.kind == tkColon:
      walk p
      fnNode.fnReturnType = p.getLiteralType()
      if fnNode.fnReturnType != ntVoid:
        walk p
      else: error(fnInvalidReturn, p.curr)
    
    # add pre initialized scope to scope var
    scope.add(fnScope)

    # parse function body
    if p.curr.kind == tkAssign:
      if fn.line == p.curr.line:
        walk p
        let stmtNode = p.parseStatement((fn, fnNode), scope = scope,
                              excludeOnly = {tkImport, tkUse, tkDotExpr},
                              returnType = fnNode.fnReturnType, isFunctionWrap = true, skipInitScope = true)
        if likely(stmtNode != nil):
          fnNode.fnBody = stmtNode
          if unlikely(isFunctionWrap):
            fnNode.fnClosure = true
            scope[^1].localScope(fnNode)
          else:
            p.globalScope(fnNode)
        else: return nil
      result = fnNode
      scope.delete(scope.high)

newPrefixProc "parseCallFnCommand":
  # Parse function calls with or without arguments,
  # looking for the following pattern: 
  # `fn myfn($a: string, $b: Int = 0): string =`
  let ident = p.curr
  walk p, 2 # (
  var
    args: seq[Node]
    types: seq[NodeType]
  while p.curr isnot tkRPAR:
    if unlikely(p.curr is tkEOF): return
    let arg = p.getPrefixOrInfix(scope, excludeOnly = {
                    tkEcho, tkReturn, tkVarDef, tkFnDef})
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
  elif scope.len > 0:
    if scope[^1].hasKey(fnIdentName):
      fn = scope[^1][fnIdentName]
    else: errorWithArgs(fnUndeclared, ident, [ident.value])
  else: errorWithArgs(fnUndeclared, ident, [ident.value])
  if likely(args.len == fn.fnParams.len):
    var i = 0  
    for pKey, pDef in fn.fnParams:
      try:
        if likely(args[i].getNodeType == pDef[1]):
          use(args[i])
        else: errorWithArgs(fnMismatchParam, ident,
                              [pDef[0], $(args[i].getNodeType), $(pDef[1])])
      except IndexDefect:
        error(fnExtraArg, ident)
      inc i 
    use fn
    let strargs = jsony.toJson(args)
    result = getMemoized(p.mCall, strargs)
    if result == nil:
      result = newFnCall(fn, args, fnIdentName, ident.value)
      p.mCall.memoize(strargs, result)
  else:
    errorWithArgs(fnExtraArg, ident,
        [ident.value, $len(fn.fnParams), $len(args)])
