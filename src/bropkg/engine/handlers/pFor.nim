proc parseFor(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  # Parse `for x in y:` loops of objects, arrays or ranges.
  let tk = p.curr
  if p.next.kind == tkVarCall:
    walk p # tkFor
    let itemToken = p.curr
    let itemNode = p.parseVarDef()
    if p.curr is tkIn and p.next.kind in {tkVarCall, tkVarTyped, tkVarCallAccessor}:
      # todo support annonymous arrays or objects
      # todo check if next token is iterable (array or object)
      walk p # tkIn
      p.curr.kind = tkVarCall
      var itemsNode = p.parsePrefix(scope = scope)
      if likely(itemsNode != nil and p.curr is tkColon):
        walk p # tkColon
        result = newForStmt(itemNode, itemsNode)
        if scope == nil:
          result.forScopes = ScopeTable()
        else:
          if not scope.hasKey(itemNode.varName):
            result.forScopes = scope
          else: error(DuplicateVarDeclaration, itemToken)
        result.forScopes[itemNode.varName] = itemNode
        result.forBody = p.parseStatement((tk, result), result.forScopes, excludeOnly, includeOnly)
        if unlikely(result.forBody == nil):
          return nil # error