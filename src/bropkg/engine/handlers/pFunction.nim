proc `$`(types: openarray[NodeType]): string =
  let t = types.map(proc(x: NodeType): string = $(x))
  add result, "|" & t.join("|")

proc identify(ident: string, types: openarray[NodeType]): string =
  result = ident
  if types.len > 0:
    add result, $(types)

proc stackFn(p: var Parser, fn: Node, types: openarray[NodeType]) =
  p.program.stack[fn.fnName.identify(types)] = fn

proc stack(scope: ScopeTable, fn: Node, types: openarray[NodeType]) =
  scope[fn.fnName.identify(types)] = fn

proc parseFn(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  let
    fn = p.curr
    fnName = p.next
    scope = if scope == nil: ScopeTable() else: scope
  walk p # `fn`
  result = newFunction(fnName)
  walk p # function identifier
  var types: seq[NodeType]
  if p.curr.kind == tkLPAR and p.curr.line == fn.line:
    # parse function parameters
    walk p # (
    while p.next.kind == tkColon and p.curr.kind == tkIdentifier:
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
            result.fnParams["$" & pName.value] = ("$" & pName.value, nTyped, nil)
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
  if p.curr.kind == tkRPAR:
    walk p
    if p.curr.kind == tkColon: # parse return type
      walk p
      result.fnReturnType = p.getLiteralType()
      if result.fnReturnType != ntVoid:
        walk p
      else: error(fnInvalidReturn, p.curr)
    if p.curr.kind == tkAssign: # parse function body
      if fn.line == p.curr.line:
        walk p
        let stmtNode = p.parseStatement((fn, result), scope = scope, excludeOnly = {tkImport, tkUse})
        if stmtNode != nil:
          result.fnBody = stmtNode
          if p.lastParent != nil:
            if p.lastParent.fnName != result.fnName:
              result.fnClosure = true
              stack(scope, result, types)
            else:
              p.stackFn(result, types)
          else:
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
  var fn: Node
  let fnIdentName = identify(ident.value, types)
  if p.program.stack.hasKey(fnIdentName):
    fn = p.program.stack[fnIdentName]
  elif scope.hasKey(fnIdentName):
    fn = scope[fnIdentName]
  else:
    errorWithArgs(fnUndeclared, ident, [ident.value])
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
