# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

template collectImplicitValue() {.dirty.} =
  let implValNode = p.getPrefixOrInfix(includeOnly = {tkString, tkInteger})
  if likely(implValNode != nil):
    let nt = implValNode.getNodeType()
    fnNode.fnParams["$" & pName.value] = ("$" & pName.value, nt, implValNode)
    fnScope["$" & pName.value] = 
      newVariable("$" & pName.value, implValNode, tk = pName, isArg = true)
    fnScope["$" & pName.value].varType = nt
    types.add(nt)

newPrefixProc "parseFn":
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
    fnScope = ScopeTable()
  walk p # `fn` / `mix`
  var fnNode =
    if fn is tkMixDef:
      newMixin(fnName)
    else:
      newFunction(fnName)
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
            # Set type for current argument
            let nTyped = p.getLiteralType()
            fnNode.fnParams["$" & pName.value] = ("$" & pName.value, nTyped, nil)
            fnScope["$" & pName.value] =
              newVariable("$" & pName.value, Node(nt: nTyped), tk = pName, isArg = true)
            fnScope["$" & pName.value].varType = nTyped
            types.add(nTyped)
            walk p
            # todo support default assignments
          else: return # unexpectedToken
        else: errorWithArgs(fnAttemptRedefineIdent, pName, [pName.value])
      of tkAssign:
        # Set type and value from given assignment
        if likely(fnNode.fnParams.hasKey(pName.value) == false):
          walk p
          collectImplicitValue()
        else: errorWithArgs(fnAttemptRedefineIdent, pName, [pName.value])        
      else: break # unexpectedToken
      if p.curr.kind == tkComma:
        walk p
      else: break

  # create function identifier
  fnNode.fnIdent = identify(fnNode.fnName, types)
  # if unlikely(p.inScope(fnNode.fnIdent)):
    # errorWithArgs(fnOverload, fnName, [fnName.value])
  if p.curr is tkRP:
    walk p
    # parse function return type
    if p.curr is tkColon:
      walk p
      fnNode.fnReturnType = p.getLiteralType()
      if likely(fnNode.fnReturnType != ntVoid):
        walk p
      else:
        error(fnInvalidReturn, p.curr)
    elif fn is tkMixDef:
      fnNode.fnReturnType = ntProperty
    # parse function body, if available
    if p.curr in {tkAssign, tkLC}:
      var isCurlyBlock = p.curr.kind == tkLC
      if fn.line == p.curr.line:
        walk p
        let
          setExcl = if fn is tkFnDef: {tkImport, tkDotExpr} else: {}
          setIncl = if fn is tkFnDef: {} else: {tkIdentifier, tkEcho, tkAssert}
          stmtNode = p.parseStatement((fn, fnNode), excludeOnly = setExcl,
                        includeOnly = setIncl, returnType = fnNode.fnReturnType,
                        isFunctionWrap = true, isCurlyBlock = isCurlyBlock)
        if likely(stmtNode != nil):
          fnNode.fnBody = stmtNode
          if unlikely(isFunctionWrap):
            fnNode.fnClosure = true
            # scope[^2].localScope(fnNode)
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

newPrefixProc "parseCallFnCommand":
  # Parse function calls with or without arguments,
  # looking for the following pattern: 
  # ```bass
  # fn myfn($a: string, $b: Int = 0): string =
  # ```
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
  result = ast.newCall(ident.value, args, types)

  # now try identify the function call
  # var fn: Node
  # let fnIdentName = identify(ident.value, types)
  # if p.program.getStack.hasKey(fnIdentName):
  #   fn = p.program.getStack()[fnIdentName]
  # elif scope.len >= 1:
  #   if scope[^1].hasKey(fnIdentName):
  #     fn = scope[^1][fnIdentName]
  #   else:
  #     for mName, mIndex in p.stylesheets.keys:
  #       p.stylesheets.withFound(mName, mIndex):
  #         if value[].getStack.hasKey(fnIdentName):
  #           fn = value[].getStack()[fnIdentName]
  #           p.program.getStack()[fnIdentName] = fn
  #           break
  #     if unlikely(fn == nil):
  #       errorWithArgs(fnUndeclared, ident, [ident.value])
  # else:
    # errorWithArgs(fnUndeclared, ident, [ident.value])

  # if likely(args.len <= fn.fnParams.len):
  #   var i = 0
  #   for pKey, pDef in fn.fnParams:
  #     try:
  #       # echo args[i].getTypedValue()
  #       if likely(args[i].getTypedValue == pDef[1]):
  #         use(args[i]) # mark argument as used
  #       else: errorWithArgs(fnMismatchParam, ident, [pDef[0], $(args[i].getNodeType), $(pDef[1])])
  #     except IndexDefect:
  #       error(fnExtraArg, ident)
  #     inc i
  #   use(fn) # mark function as used
  #   # try get a memoized call
  #   let hashedIdent = hashed(fnIdentName & $(args))
  #   result = memoized(p.mCall, hashedIdent)
  #   if result == nil:
  #     # otherwise, create a new ntCallStack, then memoize it
  #     result = newFnCall(fn.fnReturnType, args, fnIdentName, ident.value)
  #     p.mCall.memoize(hashedIdent, result)
  # else:
  #   errorWithArgs(fnExtraArg, ident, [ident.value, $len(fn.fnParams), $len(args)])
