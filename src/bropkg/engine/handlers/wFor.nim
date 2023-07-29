# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

proc handleForStmt(c: var Compiler, node, parent: Node, scope: ScopeTable) =
  # Handle `for` statements
  var itemsNode = 
    if node.inItems.nt in {ntArray, ntObject}:
      node.inItems
    elif node.inItems.callNode != nil:
      node.inItems.callNode
    else:
      assert scope != nil
      scope[node.inItems.callIdent]
  node.forStorage = ScopeTable()
  node.forStorage[node.forItem.varName] = node.forItem
  var ix = 1
  case itemsNode.nt:
  of ntVariable:
    # Array or Object iterator via Variable call
    let items = itemsNode.varValue.itemsVal
    for i in 0 .. items.high:
      let len = node.forBody.stmtList.len
      node.forStorage[node.forItem.varName].varValue = items[i]
      for ii in 0 .. node.forBody.stmtList.high:
        c.handleInnerNode(node.forBody.stmtList[ii], parent, node.forStorage, len, ix)
  of ntArray:
    # Array iterator
    for i in 0 .. itemsNode.itemsVal.high:
      let len = node.forBody.stmtList.len
      node.forStorage[node.forItem.varName].varValue = itemsNode.itemsVal[i]
      for n in node.forBody.stmtList:
        c.handleInnerNode(n, parent, node.forStorage, len, ix)
  of ntStream:
    # Write JSON/YAML streams
    for item in items(itemsNode.streamContent):
      let len = node.forBody.stmtList.len
      node.forStorage[node.forItem.varName].varValue = newStream item
      for n in node.forBody.stmtList:
        c.handleInnerNode(n, parent, node.forStorage, len, ix)
  of ntAccessor:
    var x: Node 
    if itemsNode.accessorType == ntArray:
      x = walkAccessorStorage(itemsNode.accessorStorage, itemsNode.accessorKey, scope)
      for i in 0 .. x.itemsVal.high:
        let len = node.forBody.stmtList.len
        node.forStorage[node.forItem.varName].varValue = x.itemsVal[i]
        for nodeBody in node.forBody.stmtList:
          c.handleInnerNode(nodeBody, parent, node.forStorage, len, ix)
    else:
      echo "todo implement ntObject field iterator"
  else: discard