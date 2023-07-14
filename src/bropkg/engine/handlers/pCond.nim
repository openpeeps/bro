newPrefixProc "parseCond":
  let tk = p.curr # tkIf
  walk p
  let compNode = p.getPrefixOrInfix(scope)
  if likely(compNode != nil):
    if p.curr.kind == tkColon:
      walk p # tkColon
      result = newIf(compNode)
      let ifStmt = p.parseStatement((tk, result), scope, excludeOnly, includeOnly)
      if likely(ifStmt != nil):
        result.ifStmt = ifStmt
      else: return
      ifStmt.clean()
      while p.curr is tkElif:
        walk p # tkElif
        let elifCompNode = p.getPrefixOrInfix(scope)
        if likely(elifCompNode != nil and p.curr is tkColon):
          walk p # tkColon
          let elifNode = p.parseStatement((tk, result), scope, excludeOnly, includeOnly)
          if likely(elifNode != nil):
            add result.elifStmt, (elifCompNode, elifNode)
          else: return
        else: return
      if p.curr is tkElse:
        if p.next is tkColon:
          walk p, 2 # tkElse, tkColon
          let elseNode = p.parseStatement((tk, result), scope, excludeOnly, includeOnly)
          if likely(elseNode != nil):
            result.elseStmt = elseNode
          else: return
        else: error(BadIndentation, p.curr)
    else: error(BadIndentation, p.curr)

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
      while p.curr is tkOf and p.curr.pos == tkOfTuple.pos:
        walk p # tkOf
        let tkOfIdent = p.curr # literal or variable
        let ofCond = p.parsePrefix(excludeOnly = {tkEcho, tkReturn, tkFnDef}, scope = scope)
        if ofCond != nil:
          checkColon
          if likely(ofCond.getNodeType == caseVarType):
            let ofBody = p.parseStatement((tkOfTuple, caseNode), scope, excludeOnly, includeOnly)
            if likely(ofBody != nil):
              add caseNode.caseCond, (ofCond, ofBody)
            else: error(BadIndentation, p.curr)
          else: errorWithArgs(caseInvalidValueType, tkOfIdent, [$(ofCond.getNodeType), $(caseVarType)])
        else: error(caseInvalidValue, p.curr)
      if p.curr is tkElse:
        walk p
        checkColon
        let elseBody = p.parseStatement((tkOfTuple, caseNode), scope, excludeOnly, includeOnly) 
        if likely(elseBody != nil):
          caseNode.caseElse = elseBody
        else: error(caseInvalidValue, p.curr)
      return caseNode
    error(BadIndentation, p.curr)