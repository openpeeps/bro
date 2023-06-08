proc parseCaseStmt(p: var Parser, scope: ScopeTable = nil): Node =
  # Parse a `case` block statement
  let tk = p.curr # of
  walk p
  if p.curr.kind == tkVarCall:
    if p.next.kind == tkColon:
      let callNode = p.parseVariableCall(scope)
      result = newCaseStmt(callNode)
    walk p # :
    # handle one or more `of` statements
    if p.curr.kind == tkOF:
      var tkOfTuple = p.curr
      while p.curr.kind == tkOF and p.curr.pos == tkOfTuple.pos:
        tkOfTuple = p.curr
        if p.next.kind in tkAssignableValue:
          walk p
          while p.curr.kind in tkAssignableValue and p.curr.kind != tkEOF:
            var caseCondTuple: CaseCondTuple
            caseCondTuple.condOf = p.getAssignableNode(scope)
            while p.curr.pos > tkOfTuple.pos and p.curr.kind != tkEOF:
              var subNode: Node
              case p.curr.kind
              of tkIdentifier:
                subNode = p.parseProperty(scope)
              else:
                subNode = p.parse(scope)
              if subNode != nil:
                caseCondTuple.body.add(subNode)
              else: return
            result.caseCond.add caseCondTuple
            if caseCondTuple.body.len == 0:
              error(InvalidIndentation, p.curr)
              return
        else:
          error(InvalidValueCaseStmt, p.curr)
          return
      # handle `else` statement
      if p.curr.kind == tkElse:
        if p.curr.pos == tkOfTuple.pos:
          let tkElse = p.curr
          walk p
          while p.curr.kind != tkEOF and p.curr.pos > tkElse.pos:
            var subNode: Node
            case p.curr.kind
            of tkIdentifier:
              subNode = p.parseProperty(scope)
            else:
              subNode = p.parse(scope)
            if subNode != nil:
              result.caseElse.add(subNode)
          if result.caseElse.len == 0:
            error(InvalidIndentation, p.curr)
    else: error(InvalidValueCaseStmt, p.curr)
  else: error(InvalidSyntaxCaseStmt, p.curr)