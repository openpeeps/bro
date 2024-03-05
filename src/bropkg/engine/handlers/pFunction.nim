# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

prefixHandle parseFn:
  # Parse function/mixin definitions,
  # Declaring a function looks like this:
  #```bass
  # fn hello*(name: string): string =
  #   return $name
  #```
  #
  # Declaring a mixin (aka template), which is a
  # function with less freedom and no return type:
  #```bass
  # mix font(size: px, family: string) =
  #   font-size: $size
  #   font-family: $family
  #```
  let
    fn = p.curr
    fnName = p.next
    # fnScope = ScopeTable()
  walk p # `fn` / `mix`
  var fnNode =
    if fn is tkMixDef:
      ast.newMixin(fnName, fn)
    else:
      ast.newFunction(fnName, fn)
  var exported =
    if p.next is tkMultiply:
      walk p
      true
    else: false
  walk p # function identifier
  var types: seq[NodeType]
  if likely(p.curr is tkLP and p.curr.line == fn.line):
    # parse function parameters
    walk p # (
    while p.curr isnot tkRP:
      let pName = p.curr # param name
      walk p
      case p.curr.kind
      of tkColon:
        if likely(fnNode.fnParams.hasKey(pName.value) == false):
          walk p
          case p.curr.kind:
          of tkTypedLiterals:
            let nTyped = p.getLiteralType()
            fnNode.fnParams["$" & pName.value] = ("$" & pName.value, nTyped, nil)
            # fnScope["$" & pName.value] =
              # newVariable("$" & pName.value, Node(nt: nTyped), tk = pName, isArg = true)
            # fnScope["$" & pName.value].varType = nTyped
            types.add(nTyped)
            walk p
            # todo support default assignments
          else: return # unexpectedToken
        else: errorWithArgs(fnRedefineIdent, pName, [pName.value])
      of tkAssign:
        # Set type from implicit value
        if likely(fnNode.fnParams.hasKey(pName.value) == false):
          walk p
          let implValNode = p.getPrefixOrInfix(includeOnly = {tkString, tkInteger})
          if likely(implValNode != nil):
            let nt = implValNode.getNodeType()
            fnNode.fnParams["$" & pName.value] = ("$" & pName.value, nt, implValNode)
            types.add(nt)
        else: errorWithArgs(fnRedefineIdent, pName, [pName.value])        
      else: break # unexpectedToken
      if p.curr.kind == tkComma:
        walk p
      else: break

  # create function identifier
  fnNode.fnIdent = identify(fnNode.fnName, types)
  if p.curr is tkRP:
    walk p
    # parse function return type
    if p.curr is tkColon:
      walk p
      fnNode.fnReturnType = p.getLiteralType()
      if unlikely(fnNode.fnReturnType == ntInvalid):
        error(fnInvalidReturn, p.curr)
      walk p
    elif fn is tkMixDef:
      fnNode.fnReturnType = ntProperty
    # parse function body, if available
    if p.curr in {tkAssign, tkLC}:
      var isCurlyBlock = p.curr.kind == tkLC
      if fn.line == p.curr.line:
        walk p
        let
          setExcl = if fn is tkFnDef: {tkImport, tkDot} else: {}
          setIncl = if fn is tkFnDef: {} else: {tkIdentifier, tkEcho, tkAssert}
          stmtNode = p.parseStatement((fn, fnNode), excludeOnly = setExcl,
                        includeOnly = setIncl, returnType = fnNode.fnReturnType,
                        isFunctionWrap = true, isCurlyBlock = isCurlyBlock)
        if likely(stmtNode != nil):
          fnNode.fnBody = stmtNode
          if unlikely(isFunctionWrap):
            fnNode.fnClosure = true
            if unlikely(exported):
              error(fnAnoExport, fnName)
          else:
            fnNode.fnExport = exported
        else: return nil
      result = fnNode
    else:
      # create a forward declaration
      fnNode.fnFwdDecl = true
      fnNode.fnExport = exported
      result = fnNode
    case p.program.sheetType
    of styleTypeLibrary:
      fnNode.fnSource = p.program.sourcePath
    else: discard # todo

prefixHandle pFunctionCall:
  # parse a function call
  if p.curr is tkMixCall:
    walk p 
  let ident = p.curr
  walk p, 2 # (
  var args: seq[Node]
  var types: seq[NodeType]
  while p.curr isnot tkRP:
    if unlikely(p.curr is tkEOF): return
    let arg = p.getPrefixOrInfix(includeOnly = tkAssignable)
    if likely(arg != nil):
      add args, arg
      add types, arg.nt
    else: return
    if p.curr is tkComma:
      walk p
  walk p # )
  result = ast.newCall(ident, args, types)
  # case p.curr.kind
  # of tkDot:
  #   if p.curr.line == result.meta[0]:
  #     # var dotExpr = p.parseDotExpr(nil)
  #     # dotExpr.lhs = dotExpr.rhs
  #     # dotExpr.rhs = result
  #     return p.parseDotExpr(result)
  # else: discard