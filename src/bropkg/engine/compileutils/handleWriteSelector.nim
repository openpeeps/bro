proc writeAvailableConcat(c: var Compiler, node: Node, scope: ScopeTable = nil) =
  for idConcat in node.identConcat:
    case idConcat.nt
    of NTCall:
      var scopeVar: Node
      if idConcat.callNode.varValue != nil:
        c.writeVal(idConcat, nil)
      else:
        scopeVar = scope[idConcat.callNode.varName]
        var varValue = scopeVar.varValue
        case varValue.val.nt
        of NTColor:
          # todo handle colors at parser level
          idConcat.callNode.varValue = varValue
          c.writeVal(idConcat, nil, varValue.val.cVal[0] == '#')
        else:
          idConcat.callNode.varValue = varValue
          c.writeVal(idConcat, nil)
    of NTString, NTInt, NTFloat, NTBool:
      c.writeVal(idConcat, nil)
    else: discard

proc getSelectorName(node: Node): string =
  if node.parents.len != 0:
    return node.parents.join(" ") & spaces(1) & prefix(node)
  return prefix(node)

proc writeSelector(c: var Compiler, node: Node, scope: ScopeTable = nil, data: Node = nil, parentSelector = "") =
  var
    skipped: bool
    length = node.properties.len
  if length != 0:
    add c.css, getSelectorName(node)
    c.writeAvailableConcat(node, scope)
    add c.css, strCL # {
    c.handleChildNodes(node, scope, skipped, length)
    add c.css, strCR # }
  if likely(node.innerNodes.len != 0):
    for innerNodeKey, innerNode in node.innerNodes:
      # add c.css, prefix(node) & spaces(1)
      c.write(innerNode, scope, node)

proc writeClass(c: var Compiler, node: Node, scope: ScopeTable) =
  c.writeSelector(node)
  if unlikely(node.pseudo.len != 0):
    for k, pseudoNode in node.pseudo:
      c.writeSelector(pseudoNode, scope)

proc writeID(c: var Compiler, node: Node, scope: ScopeTable) =
  c.writeSelector(node)
  if unlikely(node.pseudo.len != 0):
    for k, pseudoNode in node.pseudo:
      c.writeSelector(pseudoNode, scope)

proc writeTag(c: var Compiler, node: Node, scope: ScopeTable) =
  c.writeSelector(node)
  if unlikely(node.pseudo.len != 0):
    for k, pseudoNode in node.pseudo:
      c.writeSelector(pseudoNode, scope)

proc handleChildNodes(c: var Compiler, node: Node, scope: ScopeTable = nil,
                      skipped: var bool, length: int) =
  var i = 1 
  for k, v in node.properties:
    case v.nt:
    of NTProperty:
      c.writeProps(v, k, i, length, scope)
    of NTExtend:
      for eKey, eProp in v.extendProps.pairs():
        var ix = 0
        c.writeProps(eProp, eKey, ix, v.extendProps.len, scope)
    of NTForStmt:
      case node.inItems.callNode.nt:
      of NTVariableValue:
        let items = node.inItems.callNode.varValue.arrayVal
      of NTJsonValue:
        let items = node.inItems.callNode.jsonVal
      else: discard
    of NTCaseStmt:
      discard
    of NTCondStmt:
      c.handleCondStmt(v, scope)
    else: discard