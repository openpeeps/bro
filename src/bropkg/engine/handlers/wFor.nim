proc handleForStmt(c: var Compiler, node, parent: Node, scope: ScopeTable) =
  # Handle `for` statements
  var itemsNode = 
    if node.inItems.callNode != nil:
      node.inItems.callNode
    else:
      assert scope != nil
      scope[node.inItems.callIdent]
  node.forStorage = ScopeTable()
  node.forStorage[node.forItem.varName] = node.forItem
  case itemsNode.nt:
  of ntVariable:
    var ix = 1
    let items = node.inItems.callNode.varValue.itemsVal
    for i in 0 .. items.high:
      node.forStorage[node.forItem.varName].varValue = items[i]
      for k, v in scope:
        node.forStorage[k] = v
      for ii in 0 .. node.forBody.stmtList.high:
        c.handleInnerNode(node.forBody.stmtList[ii], parent,
                  node.forStorage, node.forBody.stmtList.len, ix)
  of ntArray:
    var ix = 1
    let items = itemsNode.itemsVal
    for i in 0 .. items.high:
      node.forStorage[node.forItem.varName].varValue = items[i]
      for k, v in scope:
        node.forStorage[k] = v
      for ii in 0 .. node.forBody.stmtList.high:
        c.handleInnerNode(node.forBody.stmtList[ii], parent,
                  node.forStorage, node.forBody.stmtList.len, ix)
  of ntStream:
    var ix = 1
    for item in items(node.inItems.callNode.streamContent):
      node.forStorage[node.forItem.varName].varValue = newStream item
      for i in 0 .. node.forBody.stmtList.high:
        c.handleInnerNode(node.forBody.stmtList[i], parent,
                    node.forStorage, node.forBody.stmtList.len, ix)
  else: discard