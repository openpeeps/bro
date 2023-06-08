proc parseForStmt(p: var Parser, scope: ScopeTable = nil): Node =
  ## Parse `for x in y` loop statement
  var item: Node
  let tk = p.curr
  let tkNext = p.next
  item = newVariable(tkNext)
  walk p, 2
  if p.curr.kind == tkIn and p.next.kind in {tkVarCall, tkVarCallAccessor}:
    walk p # in
    var items = p.parse()
    if items == nil: return
    case p.curr.kind
    of tkColon:
      walk p
      if p.curr.line > tk.line and p.curr.col > tk.col:
        var forNode = newForStmt(item, items)
        if scope == nil:
          forNode.forScopes = ScopeTable()
        else:
          if not scope.hasKey(item.varName):
            forNode.forScopes = scope
          else: error(DuplicateVarDeclaration, tkNext)
        forNode.forScopes[item.varName] = item
        while p.curr.col > tk.col:
          if p.curr.kind == tkEOF: break
          let forBodyNode = p.parse(forNode.forScopes)
          if forBodyNode != nil:
            # forNode.aotStmts.add(infixNode)
            forNode.forBody.add forBodyNode
          else: return
        return forNode
      error(InvalidIndentation, p.curr)
    else: error(UnexpectedToken, p.curr)
  else: error(InvalidSyntaxLoopStmt, p.curr)