# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

newPrefixProc "parseCond":
  let tk = p.curr # tkIf
  walk p
  let
    # due to a parser limitation, we'll have to pass both,
    # `tkIdentifier` and `tkFnCall` to `includeOnly` to allow function calls.
    # where `tkFnCall` is a simple token used to determine what kind of identifier
    # is expected via the `includeOnly` set  
    compTokens = {tkVarCall, tkInteger, tkString, tkBool, tkColor, tkIdentifier, tkFnCall} + tkNamedColors 
    compNode = p.getPrefixOrInfix(includeOnly = compTokens, scope = scope)
  var ifNode: Node
  if likely(compNode != nil):
    if p.curr.kind == tkColon:
      walk p # tkColon
      ifNode = newIf(compNode)
      
      # parse `if` branch
      let ifStmt = p.parseStatement((tk, ifNode), scope, excludeOnly,
                      includeOnly, returnType, isFunctionWrap)
      if likely(ifStmt != nil):
        ifNode.ifStmt = ifStmt
      else: error(badIndentation, p.curr)
      ifStmt.cleanup # out of scope

      # parse `elif` branches
      while p.curr is tkElif:
        walk p # tkElif
        let elifCompNode = p.getPrefixOrInfix(includeOnly = compTokens, scope = scope)
        if likely(elifCompNode != nil and p.curr is tkColon):
          walk p # tkColon
          let elifNode = p.parseStatement((tk, ifNode), scope, excludeOnly,
                          includeOnly, returnType, isFunctionWrap)
          if likely(elifNode != nil):
            add ifNode.elifStmt, (elifCompNode, elifNode)
          else:
            error(badIndentation, p.curr)
          elifNode.cleanup # out of scope
        else: return nil

      # parse `else` branch
      if p.curr is tkElse:
        if p.next is tkColon:
          walk p, 2 # tkElse, tkColon
          let elseNode = p.parseStatement((tk, ifNode), scope, excludeOnly,
                            includeOnly, returnType, isFunctionWrap)
          if likely(elseNode != nil):
            ifNode.elseStmt = elseNode
          else:
            error(badIndentation, p.curr)
          elseNode.cleanup # out of scope
        else:
          error(badIndentation, p.curr)
      scope.delete(scope.high)
      return ifNode
    error(badIndentation, p.curr)

newPrefixProc "parseCase":
  let tk = p.curr # case
  walk p # tkCase
  if p.curr is tkVarCall: # todo support function calls
    let
      caseVar = p.parseCallCommand(scope)
      caseVarType = caseVar.getTypedValue
      caseNode = newCaseStmt(caseVar)
    if p.curr is tkOf and p.curr.pos > tk.pos:
      let tkOfTuple = p.curr
      # parse `of` branches
      while p.curr is tkOf and p.curr.pos == tkOfTuple.pos:
        walk p # tkOf
        let tkOfIdent = p.curr # literal or variable
        let caseOf = p.parsePrefix(excludeOnly = {tkEcho, tkReturn, tkFnDef}, scope = scope, returnType = returnType)
        if caseOf != nil:
          checkColon
          if likely(caseOf.getNodeType == caseVarType):
            let caseBody = p.parseStatement((tkOfTuple, caseNode), scope, excludeOnly,
                          includeOnly, returnType, isFunctionWrap)
            if likely(caseBody != nil):
              add caseNode.caseCond, (caseOf, caseBody)
              # caseBody.cleanup # out of scope
              scope.delete(scope.high)
            else: error(badIndentation, p.curr)
          else: errorWithArgs(caseInvalidValueType, tkOfIdent, [$(caseOf.getNodeType), $(caseVarType)])
        else: error(caseInvalidValue, p.curr)
      
      if p.curr.pos > tk.pos and p.curr isnot tkElse:
        error(badIndentation, p.curr)
      
      # parse `else` branch
      if p.curr is tkElse:
        walk p
        checkColon
        let elseBody = p.parseStatement((tkOfTuple, caseNode), scope, excludeOnly,
                        includeOnly, returnType, isFunctionWrap) 
        if likely(elseBody != nil):
          caseNode.caseElse = elseBody
        else: error(caseInvalidValue, p.curr)
        # elseBody.cleanup # out of scope
        scope.delete(scope.high)
      return caseNode
    error(badIndentation, p.curr)