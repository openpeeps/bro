# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

proc handleForStmt(c: Compiler, node, parent: Node, scope: ScopeTable) =
  # Handle `for` statements
  var
    ix = 1
    itemsNode = 
      if node.inItems.nt in {ntArray, ntObject}:
        node.inItems
      elif node.inItems.callNode != nil:
        node.inItems.callNode
      else:
        assert scope != nil
        scope[node.inItems.callIdent]
  node.forStorage = ScopeTable()
  node.forStorage[node.forItem.varName] = node.forItem
  case itemsNode.nt:
  of ntVariable:
    # Array or Object iterator via Variable call
    let items = itemsNode.varValue.arrayItems
    let len = node.forBody.stmtList.len
    for item in 0 .. items.high:
      node.forStorage[node.forItem.varName].varValue = items[item]
      for iitem in 0 .. node.forBody.stmtList.high:
        c.handleInnerNode(node.forBody.stmtList[iitem], parent, node.forStorage, len, ix)
  of ntArray:
    # Array iterator
    let len = node.forBody.stmtList.len
    for i in 0 .. itemsNode.arrayItems.high:
      node.forStorage[node.forItem.varName].varValue = itemsNode.arrayItems[i]
      for n in node.forBody.stmtList:
        c.handleInnerNode(n, parent, node.forStorage, len, ix)
  of ntStream:
    # Write JSON/YAML streams
    let len = node.forBody.stmtList.len
    for item in items(itemsNode.streamContent):
      node.forStorage[node.forItem.varName].varValue = newStream item
      for n in node.forBody.stmtList:
        c.handleInnerNode(n, parent, node.forStorage, len, ix)
  of ntAccessor:
    var x: Node 
    if itemsNode.accessorType == ntArray:
      x = walkAccessorStorage(itemsNode.accessorStorage, itemsNode.accessorKey, scope)
      let len = node.forBody.stmtList.len
      for i in 0 .. x.arrayItems.high:
        node.forStorage[node.forItem.varName].varValue = x.arrayItems[i]
        for nodeBody in node.forBody.stmtList:
          c.handleInnerNode(nodeBody, parent, node.forStorage, len, ix)
      return
    x = walkAccessorStorage(itemsNode.accessorStorage, itemsNode.accessorKey, scope)
    if x.nt == ntObject:
      let len = node.forBody.stmtList.len
      for i, y in x.pairsVal:
        node.forStorage[node.forItem.varName].varValue = y
        for nodeBody in node.forBody.stmtList:
          c.handleInnerNode(nodeBody, parent, node.forStorage, len, ix)
    elif x.nt == ntStream:
      # let len = node.forBody.stmtList.len
      # for i, y in x.streamContent:
      #   node.forStorage[node.forItem.varName].varValue = newStream y
      #   for nodeBody in node.forBody.stmtList:
      #     c.handleInnerNode(nodeBody, parent, node.forStorage, len) 
      let len = node.forBody.stmtList.len
      for item in items(x.streamContent):
        node.forStorage[node.forItem.varName].varValue = newStream item
        for n in node.forBody.stmtList:
          c.handleInnerNode(n, parent, node.forStorage, len, ix)     
  else: discard