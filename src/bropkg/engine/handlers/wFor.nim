# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro


newHandler forBlock:
  #[
  Handles `for` block statements
  ]#
  var ix = 1
  var itemsNode =
    case node.inItems.nt
    of {ntArray, ntObject}:
      node.inItems
    of ntCall:
      c.nodeEvaluator(node.inItems, scope)
    of ntCallFunction:
      c.nodeEvaluator(node.inItems, scope)
    else: nil
  if likely(itemsNode != nil):
    case itemsNode.nt
    of ntArray:
      let len = itemsNode.arrayItems.len
      for item in itemsNode.arrayItems:
        var forScope = ScopeTable()
        forScope[node.forItem[0].varName] = node.forItem[0]
        forScope[node.forItem[0].varName].varMod = item
        add scope, forScope
        for innerNode in node.forBody.stmtList:
          c.handleInnerNode(innerNode, parent, scope, len, ix)
        scope.delete(scope.high) # out of scope
    of ntObject:
      let len = itemsNode.pairsVal.len
      if likely(node.forItem[1] != nil):
        # yields all `$k, $v` pairs of the object
        for k, v in itemsNode.pairsVal:
          var forScope = ScopeTable()
          forScope[node.forItem[0].varName] = node.forItem[0]
          forScope[node.forItem[0].varName].varMod = ast.newString(k)
          forScope[node.forItem[1].varName] = node.forItem[1]
          forScope[node.forItem[1].varName].varMod = v
          add scope, forScope
          for innerNode in node.forBody.stmtList:
            c.handleInnerNode(innerNode, parent, scope, len, ix)
          scope.delete(scope.high)
      else:
        # yields all `$k` keys of the object
        for k in keys(itemsNode.pairsVal):
          var forScope = ScopeTable()
          forScope[node.forItem[0].varName] = node.forItem[0]
          forScope[node.forItem[0].varName].varMod = ast.newString(k)
          add scope, forScope
          for innerNode in node.forBody.stmtList:
            c.handleInnerNode(innerNode, parent, scope, len, ix)
          scope.delete(scope.high)
    of ntStream:
      case itemsNode.streamContent.kind
      of JArray:
        if unlikely(node.forItem[1] != nil):
          compileErrorWithArgs(forInvalidIteration)
        let len = node.forBody.stmtList.len
        for item in items(itemsNode.streamContent):
          var forScope = ScopeTable()
          forScope[node.forItem[0].varName] = node.forItem[0]
          forScope[node.forItem[0].varName].varMod =
            case item.kind
            of JArray, JObject: newStream(item)
            else: item.toNode
          add scope, forScope
          for innerNode in node.forBody.stmtList:
            c.handleInnerNode(innerNode, parent, scope, len, ix)
          scope.delete(scope.high)
      of JObject:
        # yields all `$k, $v` pairs of the object
        let len = node.forBody.stmtList.len
        if likely(node.forItem[1] != nil):
          for k, v in pairs(itemsNode.streamContent):
            var forScope = ScopeTable()
            forScope[node.forItem[0].varName] = node.forItem[0]
            forScope[node.forItem[0].varName].varMod = ast.newString(k)
            forScope[node.forItem[1].varName] = node.forItem[1]
            forScope[node.forItem[1].varName].varMod =
              case v.kind
              of JArray, JObject: newStream(v)
              else: v.toNode
            add scope, forScope
            for innerNode in node.forBody.stmtList:
              c.handleInnerNode(innerNode, parent, scope, len, ix)
            scope.delete(scope.high)
        else:
          # yields all `$k` keys of the object
          for k in keys(itemsNode.streamContent):
            var forScope = ScopeTable()
            forScope[node.forItem[0].varName] = node.forItem[0]
            forScope[node.forItem[0].varName].varMod = ast.newString(k)
            add scope, forScope
            for innerNode in node.forBody.stmtList:
              c.handleInnerNode(innerNode, parent, scope, len, ix)
            scope.delete(scope.high)   
      else: compileErrorWithArgs(forInvalidIteration, node.meta)
    else: compileErrorWithArgs(forInvalidIterationGot, [$(itemsNode.nt)], node.meta)
  else: compileErrorWithArgs(forInvalidIterationGot, ["null"], node.meta)
