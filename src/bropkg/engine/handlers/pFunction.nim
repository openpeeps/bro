proc `$`(types: openarray[NodeType]): string =
  let t = types.map(proc(x: NodeType): string = $(x))
  add result, "|" & t.join("|")

proc identifyFn(ident: string, types: openarray[NodeType]): string =
  result = ident
  if types.len > 0:
    add result, $(types)

proc stackFn(p: var Parser, fn: Node, types: openarray[NodeType]) =
  p.program.stack[fn.fnName.identifyFn(types)] = fn

proc parseFn(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  let
    fn = p.curr
    fnName = p.next
    scope = ScopeTable()
  walk p # `fn`
  result = newFunction(fnName)
  walk p # function identifier
  var types: seq[NodeType]
  if p.curr.kind == tkLPAR and p.curr.line == fn.line:
    # parse function parameters
    walk p # (
    while p.next.kind == tkColon and p.curr.kind == tkVarTyped:
      let pName = p.curr
      walk p
      case p.curr.kind
      of tkColon:
        if likely(result.fnParams.hasKey(pName.value) == false):
          walk p
          case p.curr.kind:
          of tkTypedLiterals:
            # Set type for current argument
            let nTyped = p.getLiteralType()
            result.fnParams[pName.value] = (pName.value, nTyped, nil)
            scope[pName.value] = nil
            types.add(nTyped)
            walk p
            # todo support default assignments
          else: return # UnexpectedToken
        else: errorWithArgs(fnAttemptRedefineIdent, pName, ["$" & pName.value])
      of tkAssign:
        # Set type and value from given assignment 
        discard # todo
      else: break # UnexpectedToken
      if p.curr.kind == tkComma:
        walk p
      else: break
  
  if p.curr.kind == tkRPAR:
    walk p
    if p.curr.kind == tkColon: # parse return type
      walk p
      result.fnReturnType = p.getLiteralType()
      if result.fnReturnType != ntVoid:
        walk p
      else: error(FunctionInvalidReturn, p.curr)
    if p.curr.kind == tkAssign: # parse function body
      if fn.line == p.curr.line:
        walk p
        let stmtNode = p.parseStatement((fn, result), excludeOnly = {tkImport, tkFnDef}, scope = scope)
        if stmtNode != nil:
          result.fnBody = stmtNode
          p.stackFn(result, types)
    else: return nil

proc parseCallFnCommand(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  # Parse function calls with/without arguments,
  # matching the following pattern: `fn ($a: String, $b: Int ...): String =`
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
  let fnIdentStr = identifyFn(ident.value, types)
  if p.program.stack.hasKey(fnIdentStr):
    let fn = p.program.stack[fnIdentStr]
    if likely(args.len == fn.fnParams.len):
      var i = 0  
      for pKey, pDef in fn.fnParams:
        # check if given arguments match with function
        try:
          if likely(args[i].getNodeType == pDef[1]):
            use(args[i])
          else:
            errorWithArgs(FunctionMismatchParam, ident, [pDef[0], $(args[i].getNodeType), $(pDef[1])])
        except IndexDefect:
          error(FunctionExtraArg, ident)
        inc i 
      use fn
      result = newFnCall(fn, args, fnIdentStr)
    else:
      errorWithArgs(FunctionExtraArg, ident, [ident.value, $len(fn.fnParams), $len(args)])
  else: errorWithArgs(UndeclaredFunction, ident, [ident.value])
