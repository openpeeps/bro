# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

newPrefixProc "parseFor":
  # Parse `for x in y:` loops of objects, arrays or ranges.
  let tk = p.curr
  if p.next.kind == tkVarCall:
    walk p # tkFor
    let
      itemToken = p.curr
      itemNode = p.parseVarDef(scope)
    itemNode.varImmutable = true # `$item` cannot be redeclared/reassigned in this scope
    itemNode.varInitType = ntArray
    if p.curr is tkIn and p.next.kind in {tkVarCall, tkVarTyped, tkLB, tkLC}:
      # todo when var, check if is iterable (array or object)
      walk p # tkIn
      if p.curr.kind notin {tkLB, tkLC}:
        p.curr.kind = tkVarCall
      var itemsNode = p.parsePrefix(scope = scope)
      itemNode.varType = itemsNode.getTypedValue
      if likely(itemsNode != nil and p.curr is tkColon):
        walk p # tkColon
        result = newForStmt(itemNode, itemsNode)
        # add a pre-initialized ScopeTable to seq[ScopeTable]
        let forScope = ScopeTable()
        forScope[itemNode.varName] = itemNode
        scope.add(forScope)
        # parse for statement
        result.forBody = p.parseStatement((tk, result), scope, excludeOnly, includeOnly, skipInitScope = true)
        if likely(result.forBody != nil):
          result.forBody.cleanup(itemNode.varName)
        else: return nil