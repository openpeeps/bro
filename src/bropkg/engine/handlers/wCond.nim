proc handleCondStmt(c: var Compiler, node, parent: Node, scope: ScopeTable) =
  # Compiler handler to evaluate conditional statements `if`, `elif`, `else`
  var ix = 0
  var tryElse: bool
  if evalInfix(node.ifInfix.infixLeft, node.ifInfix.infixRight,
            node.ifInfix.infixOp, scope):
    for ifNode in node.ifStmt.stmtList:
      c.handleInnerNode(ifNode, parent, scope, node.ifStmt.stmtList.len, ix)
    return # condition is truthy
  if node.elifStmt.len > 0:
    for elifBranch in node.elifStmt: # walk through seq[Node] of `elif` statements
      case elifBranch.comp.nt
      of ntInfix:
        if evalInfix(elifBranch.comp.infixLeft, elifBranch.comp.infixRight,
                    elifBranch.comp.infixOp, scope):
          ix = 0
          for elifNode in elifBranch.body.stmtList:
            c.handleInnerNode(elifNode, parent, scope, elifBranch.body.stmtList.len, ix)
          return # condition is truthy
      else:
        discard # handle variables or boolean literals
  if node.elseStmt != nil:
    ix = 0
    for elseNode in node.elseStmt.stmtList:
      c.handleInnerNode(elseNode, parent, scope, node.elseStmt.stmtList.len, ix)

proc handleCaseStmt(c: var Compiler, node: Node, scope: ScopeTable) =
  # Compiler handler to evaluate `case` `of` statements
  var ix = 0
  for i in 0 .. node.caseCond.high:
    if evalInfix(node.caseIdent, node.caseCond[i].`of`, EQ, scope):
      for ii in 0 .. node.caseCond[i].body.stmtList.high:
        let len = node.caseCond[i].body.stmtList.len
        c.handleInnerNode(node.caseCond[i].body.stmtList[ii], node, scope, len, ix)
      return
    ix = 0
  let len = node.caseElse.stmtList.len
  for i in 0 .. node.caseElse.stmtList.high:
    c.handleInnerNode(node.caseElse.stmtList[i], node, scope, len, ix)