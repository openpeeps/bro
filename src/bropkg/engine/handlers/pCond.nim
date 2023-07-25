# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

newPrefixProc "parseCond":
  let tk = p.curr # tkIf
  walk p
  let compNode = p.getPrefixOrInfix(scope)
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
      else: error(BadIndentation, p.curr)
      # ifStmt.cleanup # out of scope

      # parse `elif` branches
      while p.curr is tkElif:
        walk p # tkElif
        let elifCompNode = p.getPrefixOrInfix(scope)
        if likely(elifCompNode != nil and p.curr is tkColon):
          walk p # tkColon
          let elifNode = p.parseStatement((tk, ifNode), scope, excludeOnly,
                          includeOnly, returnType, isFunctionWrap)
          if likely(elifNode != nil):
            add ifNode.elifStmt, (elifCompNode, elifNode)
          else:
            error(BadIndentation, p.curr)
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
            error(BadIndentation, p.curr)
          elseNode.cleanup # out of scope
        else:
          error(BadIndentation, p.curr)
      scope.delete(scope.high)
      return ifNode
    error(BadIndentation, p.curr)

newPrefixProc "parseCase":
  let tk = p.curr # case
  walk p # tkCase
  if p.curr is tkVarCall: # todo support function calls
    let
      caseVar = p.parseCallCommand(scope)
      caseVarType = caseVar.getNodeType
      caseNode = newCaseStmt(caseVar)
    if p.curr is tkOf and p.curr.pos > tk.pos:
      let tkOfTuple = p.curr
      # parse `of` branches
      while p.curr is tkOf and p.curr.pos == tkOfTuple.pos:
        walk p # tkOf
        let tkOfIdent = p.curr # literal or variable
        let ofCond = p.parsePrefix(excludeOnly = {tkEcho, tkReturn, tkFnDef}, scope = scope, returnType = returnType)
        if ofCond != nil:
          checkColon
          if likely(ofCond.getNodeType == caseVarType):
            let ofBody = p.parseStatement((tkOfTuple, caseNode), scope, excludeOnly,
                          includeOnly, returnType, isFunctionWrap)
            if likely(ofBody != nil):
              add caseNode.caseCond, (ofCond, ofBody)
            else: error(BadIndentation, p.curr)
          else: errorWithArgs(caseInvalidValueType, tkOfIdent, [$(ofCond.getNodeType), $(caseVarType)])
        else: error(caseInvalidValue, p.curr)
      
      # parse `else` branch
      if p.curr is tkElse:
        walk p
        checkColon
        let elseBody = p.parseStatement((tkOfTuple, caseNode), scope, excludeOnly,
                        includeOnly, returnType, isFunctionWrap) 
        if likely(elseBody != nil):
          caseNode.caseElse = elseBody
        else: error(caseInvalidValue, p.curr)
        caseNode.cleanup # out of scope
      return caseNode
    error(BadIndentation, p.curr)