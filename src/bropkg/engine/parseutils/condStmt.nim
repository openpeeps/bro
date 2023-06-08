proc parseInfixNode(p: var Parser, scope: ScopeTable, infixInfixNode: Node = nil): Node =
  if p.curr.kind in tkComparable or p.curr.isColor:
    let assignLeft = p.getAssignableNode(scope)
    assert assignLeft != nil # todo error msg
    var infixNode = newInfix(assignLeft)
    if p.curr.kind in tkOperators:
      infixNode.infixOp = getInfixOp(p.curr.kind, infixInfixNode != nil)
      walk p
      if p.curr.kind in tkComparable or p.curr.isColor:
        let assignRight = p.getAssignableNode(scope)
        assert assignRight != nil # todo error msg
        infixNode.infixRight = assignRight
        return infixNode
      else: error(InvalidInfixMissingValue, p.curr)
    else: error(InvalidInfixOperator, p.curr)
  else: error(InvalidInfixMissingValue, p.curr)

proc parseInfix(p: var Parser, scope: ScopeTable = nil): Node =
  result = p.parseInfixNode(scope)
  case p.curr.kind
  of tkOR, tkAltOr, tkAndAnd, tkAltAnd:
    while p.curr.kind in {tk_OR, tkAltOr, tkAndAnd, tkAltAnd}:
      let logicalOp = getInfixOp(p.curr.kind, true)
      walk p
      result = newInfix(result, p.parseInfix(scope), logicalOp)
  else: discard

proc parseCondStmt(p: var Parser, scope: ScopeTable = nil): Node =
  ## Parse a conditional statement
  let tk = p.curr
  walk p
  let infixNode = p.parseInfix(scope)
  if infixNode != nil and p.curr.kind == tkColon:
    walk p
    result = newIf(infixNode)
    # Handle `if` statement
    while p.curr.col > tk.col and p.curr.kind != tkEOF:
      var subNode: Node
      case p.curr.kind
      of tkIdentifier:
        subNode = p.parseProperty(scope)
      else: 
        subNode = p.parse(scope)
      if likely(subNode != nil):
        subNode.aotStmts.add(infixNode)
        result.ifBody.add(subNode)
      else:
        return nil
    # Handle `elif` statements
    while p.curr.kind == tkElif:
      if p.curr.col == tk.col:
        walk p
        let infixElifNode = p.parseInfix(scope)
        if infixElifNode != nil and p.curr.kind == tkColon:
          walk p # :
          var elifBody: seq[Node]
          while p.curr.col > tk.col:
            if p.curr.kind == tkIdentifier:
              var propNode = p.parseProperty(scope)
              if likely(propNode != nil):
                elifBody.add propNode
              else: break
            else:
              var subNode = p.parse(scope)
              if likely(subNode != nil):
                elifBody.add subNode
              else: break
          result.elifNode.add (infixElifNode, elifBody)
      else:
        error(BadIndentation, p.curr)
        break
  else: error(InvalidSyntaxCondStmt, p.curr)
