# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

proc handleCondStmt(c: var Compiler, node, parent: Node, scope: ScopeTable) =
  # Compiler handler to evaluate conditional statements `if`, `elif`, `else`
  var
    ix = 0
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
  if node.elifStmt.len > 0:
    for elifBranch in node.elifStmt: # walk through seq[Node] of `elif` statements
      case elifBranch.comp.nt
      of ntInfix:
        if c.evalInfix(elifBranch.comp.infixLeft, elifBranch.comp.infixRight,
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
    if c.evalInfix(node.caseIdent, node.caseCond[i].`of`, EQ, scope):
      for ii in 0 .. node.caseCond[i].body.stmtList.high:
        let len = node.caseCond[i].body.stmtList.len
        c.handleInnerNode(node.caseCond[i].body.stmtList[ii], node, scope, len, ix)
      return
    ix = 0
  let len = node.caseElse.stmtList.len
  for i in 0 .. node.caseElse.stmtList.high:
    c.handleInnerNode(node.caseElse.stmtList[i], node, scope, len, ix)