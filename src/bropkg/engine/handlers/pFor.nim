# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

prefixHandle parseFor:
  # Parse `for x in y:` loops of objects, arrays or ranges.
  let tk = p.curr
  if p.next is tkVarCall:
    walk p # tkFor
    var item = p.curr
    item.kind = tkConst # be parsed as a const
    item.value = item.value[1..^1]
    var keyNode = p.parseVarDef(item, item)
    var valNode: Node
    walk p
    if p.curr is tkIn:
      walk p # tkIn
      keyNode.varInitType = ntArray
    elif p.curr is tkComma:
      walk p
      if p.curr is tkVarCall:
        var items = p.curr
        items.kind = tkConst # be parsed as a const
        keyNode.varInitType = ntObject
        valNode = p.parseVarDef(items, items)
        walk p
        if likely(p.curr is tkIn):
          walk p
        else: return
      else: return

    if p.curr.kind in {tkVarCall, tkVarTyped, tkIdentifier, tkFnCall, tkLB, tkLC}:
      # todo when var, check if is iterable (array or object)
      if p.curr.kind notin {tkLB, tkLC} and not p.isFnCall:
        p.curr.kind = tkVarCall
      var itemsNode = p.parsePrefix()
      if likely(itemsNode != nil):
        # keyNode.varType = itemsNode.getTypedValue
        if likely(itemsNode != nil and p.curr in {tkColon, tkLC}):
          var isCurlyBlock =
            if p.curr is tkLC:
              walk p; true
            else:
              walk p; false
          result = newForStmt((keyNode, valNode), itemsNode)
          result.loopBody = p.parseStatement((tk, result), excludeOnly, includeOnly, isCurlyBlock = isCurlyBlock)
          notnil result.loopBody:
            discard