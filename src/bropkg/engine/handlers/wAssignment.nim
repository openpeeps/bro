newHandler handleVarDef:
  if likely(not inScope(node.varName, scope)):
    node.varMod = c.nodeEvaluator(node.varValue, scope)
    echo node
    c.stack(node, scope)
  else:
    compileErrorWithArgs(varRedefine, [node.varName], node.meta)

newHandler handleAssignment:
  let scopeVar = c.scoped(node.asgnVarIdent, scope)
  if likely(scopeVar != nil):
    let
      varType = scopeVar.varMod.getNodeType
      varModifier = c.nodeEvaluator(node.asgnVal, scope)
    if likely(varType == varModifier.nt):
      scopeVar.varMod = varModifier
      return
    compileErrorWithArgs(fnMismatchParam, [scopeVar.varName, $varModifier.nt, $varType], node.asgnVal.meta)
  compileErrorWithArgs(undeclaredVariable, [node.asgnVarIdent], node.meta)