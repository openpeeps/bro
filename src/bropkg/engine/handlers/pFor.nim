newPrefixProc "parseFor":
  # Parse `for x in y:` loops of objects, arrays or ranges.
  let tk = p.curr
  if p.next.kind == tkVarCall:
    walk p # tkFor
    let itemToken = p.curr
    let itemNode = p.parseVarDef(scope)
    itemNode.varImmutable = true
    if p.curr is tkIn and p.next.kind in {tkVarCall, tkVarTyped, tkVarCallAccessor, tkLB, tkLC}:
      # todo when var, check if is iterable (array or object)
      walk p # tkIn
      if p.curr.kind notin {tkLB, tkLC}:
        p.curr.kind = tkVarCall
      var itemsNode = p.parsePrefix(scope = scope)
      if likely(itemsNode != nil and p.curr is tkColon):
        walk p # tkColon
        result = newForStmt(itemNode, itemsNode)
        if scope == nil:
          var scope = ScopeTable()
        scope[itemNode.varName] = itemNode
        result.forBody = p.parseStatement((tk, result), scope, excludeOnly, includeOnly)
        if likely(result.forBody != nil):
          result.forBody.cleanExtra(itemNode.varName)
        else: return nil