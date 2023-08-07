# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

proc handleCondStmt(c: Compiler, node, parent: Node, scope: ScopeTable) =
  # Compiler handler to evaluate conditional statements `if`, `elif`, `else`
  var
    ix = 1
    tryElse: bool
    lht: Node = node.ifInfix.infixleft
    rht: Node = node.ifInfix.infixRight
  case lht.nt
  of ntCallStack:
    lht = c.handleCallStack(lht, scope)
  else: discard
  case rht.nt
  of ntCallStack:
    rht = c.handleCallStack(rht, scope)
  else: discard
  if c.evalInfix(lht, node.ifInfix.infixRight,
            node.ifInfix.infixOp, scope):
    for ifNode in node.ifStmt.stmtList:
      c.handleInnerNode(ifNode, parent, scope, node.ifStmt.stmtList.len, ix)
    return # condition is truthy
  ix = 1
  # handle elfi branches
  if node.elifStmt.len > 0:
    for elifBranch in node.elifStmt: # walk through seq[Node] of `elif` statements
      case elifBranch.comp.nt
      of ntInfix:
        if c.evalInfix(elifBranch.comp.infixLeft, elifBranch.comp.infixRight,
                    elifBranch.comp.infixOp, scope):
          for elifNode in elifBranch.body.stmtList:
            c.handleInnerNode(elifNode, parent, scope, elifBranch.body.stmtList.len, ix)
          return # condition is truthy
      else:
        discard # handle variables or boolean literals
  ix = 1
  # handle else branch
  if node.elseStmt != nil:
    let len = node.elseStmt.stmtList.len
    for elseNode in node.elseStmt.stmtList:
      c.handleInnerNode(elseNode, parent, scope, len, ix)

proc handleCaseStmt(c: Compiler, node, parent: Node, scope: ScopeTable) =
  # Compiler handler to evaluate `case` `of` statements
  var ix = 1
  for caseNode in node.caseCond:
    if c.evalInfix(node.caseIdent, caseNode.caseOf, EQ, scope):
      let len = caseNode.body.stmtList.len
      for caseBody in caseNode.body.stmtList:
        c.handleInnerNode(caseBody, parent, scope, len, ix)
      return
    ix = 1
  if node.caseElse != nil:
    let len = node.caseElse.stmtList.len
    for caseBody in node.caseElse.stmtList:
      c.handleInnerNode(caseBody, parent, scope, len, ix)