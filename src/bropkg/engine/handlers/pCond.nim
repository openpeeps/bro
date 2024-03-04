# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

prefixHandle parseCond:
  let tk = p.curr # tkIf
  walk p
  let
    # due to a parser limitation, we'll have to pass both,
    # `tkIdentifier` and `tkFnCall` to `includeOnly` to allow function calls.
    # where `tkFnCall` is a simple token used to determine what kind of identifier
    # is expected via the `includeOnly` set  
    compTokens = {tkVarCall, tkInteger, tkString, tkBool, tkColor, tkIdentifier, tkFnCall} + tkNamedColors 
    ifInfix = p.getPrefixOrInfix(includeOnly = compTokens)
  var condNode: Node
  notnil ifInfix:
    expectWalk tkColon
    condNode = ast.newNode(ntCondStmt)
    # parse `if` branch
    let ifstmt = p.parseStatement((tk, condNode), excludeOnly,
                    includeOnly, returnType, isFunctionWrap)
    notnil ifstmt:
      condNode.condIfBranch = (ifInfix, ifstmt)

    # parse `elif` branches
    while p.curr is tkElif:
      walk p # tkElif
      let elifInfix = p.getPrefixOrInfix(includeOnly = compTokens)
      notnil elifInfix:
        expectWalk tkColon
        let elifstmt = p.parseStatement((tk, condNode), excludeOnly,
                        includeOnly, returnType, isFunctionWrap)
        notnil elifstmt:
          add condNode.condElifBranch, (elifInfix, elifstmt)

    # parse `else` branch
    if p.curr is tkElse:
      walk p
      expectWalk tkColon
      let elsestmt = p.parseStatement((tk, condNode), excludeOnly,
                        includeOnly, returnType, isFunctionWrap)
      notnil elsestmt:
        condNode.condElseBranch = elsestmt
    result = condNode

prefixHandle parseCase:
  let tk = p.curr # case
  walk p # tkCase
  if p.curr is tkVarCall: # todo support function calls
    let
      caseVar = p.pIdentCall()
      # caseVarType = caseVar.getTypedValue
      caseNode = newCaseStmt(caseVar)
    var caseVarType: NodeType
    if likely(caseVarType in {ntColor, ntInt, ntFloat}):
      if p.curr is tkOf and p.curr.pos > tk.pos:
        # parse `of` branches
        let tkOfTuple = p.curr
        while p.curr is tkOf and p.curr.pos == tkOfTuple.pos:
          walk p # tkOf
          let tkOfIdent = p.curr # literal or variable
          let caseOf = p.parsePrefix(excludeOnly = {tkEcho, tkReturn, tkFnDef}, returnType = returnType)
          if caseOf != nil:
            checkColon
            # if likely(caseOf.getNodeType == caseVarType):
            let caseBody = p.parseStatement((tkOfTuple, caseNode), excludeOnly,
                          includeOnly, returnType, isFunctionWrap)
            if likely(caseBody != nil):
              add caseNode.caseCond, (caseOf, caseBody)
              # caseBody.cleanup # out of scope
              # scope.delete(scope.high)
            else: error(badIndentation, p.curr)
            # else: errorWithArgs(caseInvalidValueType, tkOfIdent, [$(caseOf.getNodeType), $(caseVarType)])
          else: error(caseInvalidValue, p.curr)
        
        if unlikely(p.curr.pos == tkOfTuple.pos and p.curr isnot tkElse):
          error(badIndentation, p.curr)
        
        # parse `else` branch
        if p.curr is tkElse:
          walk p
          checkColon
          let elseBody = p.parseStatement((tkOfTuple, caseNode), excludeOnly,
                          includeOnly, returnType, isFunctionWrap) 
          if likely(elseBody != nil):
            caseNode.caseElse = elseBody
          else: error(caseInvalidValue, p.curr)
        return caseNode
      error(badIndentation, p.curr)
    else: error(caseInvalidValue, p.curr)