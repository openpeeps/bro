proc parseCSSProperty(p: var Parser, scope: ScopeTable = nil): Node =
  discard

proc parseSelector(p: var Parser, node: Node, tk: TokenTuple, scope: ScopeTable, eatIdent = false): Node =
  if eatIdent: walk p # selector ident
  let stmtNode = p.parseStatement((tk, node), excludeOnly = {tkImport, tkFnDef}, scope = scope)
  if stmtNode != nil:
    node.selectorStmt = stmtNode
    result = node
  else: return

template handleSelectorConcat(parseWithConcat, parseWithoutConcat: untyped) {.dirty.} =
  if unlikely(p.next.kind == tkVarConcat and p.next.line == tk.line):
    walk p
    while p.curr.line == tk.line:
      # handle selector name + var concatenation
      case p.curr.kind
      of tkVarConcat:
        let concatVarCall = p.parseCallCommand(scope)
        if concatVarCall != nil:
          concatNodes.add(concatVarCall)
        else: return # UndeclaredVariable
      of tkIdentifier:
        concatNodes.add(newString(p.curr.value))
        walk p
      of tkRC:
        walk p
      of tkMinus:
        walk p # todo selector separators
      else:
        break
    parseWithConcat
  else:
    parseWithoutConcat
  p.program.selectors[tk.value] = result

proc parseSelectorClass(p: var Parser, scope: ScopeTable = nil): Node =
  let tk = p.curr
  var concatNodes: seq[Node] # ntVariable
  handleSelectorConcat:
    let node = tk.newClass(concat = concatNodes)
    p.currentSelector = node
    result = p.parseSelector(node, tk, scope)
  do:
    let node = tk.newClass()
    p.currentSelector = node
    result = p.parseSelector(node, tk, scope, eatIdent = true)
  # echo result