proc parseMultiSelector(p: var Parser, node: Node) =
  var selectors: seq[string]
  while p.curr is tkComma:
    walk p
    if p.curr notin {tkColon, tkIdentifier}:
      var selectorIdent: string
      # if p.curr.kind == tkPseudo:
      #   if not p.checkPseudoSelector():
      #     return
      selectorIdent = p.curr.value
      if selectorIdent != node.ident and selectorIdent notin selectors:
        add selectors, selectorIdent
        walk p
      else:
        errorWithArgs(DuplicateSelector, p.curr, [selectorIdent])
  node.multipleSelectors = selectors
  setLen(selectors, 0)
  if p.lastParent != nil:
    if p.lastParent.parents.len != 0:
      node.parents = concat(p.lastParent.parents, @[p.lastParent.ident])
    else:
      add node.parents, p.lastParent.ident
    p.lastParent = nil

proc parseSelector(p: var Parser, node: Node, tk: TokenTuple, scope: ScopeTable, eatIdent = false): Node =
  if eatIdent: walk p # selector ident
  p.parseMultiSelector(node)
  p.parseSelectorStmt((tk, node), scope = scope, excludeOnly = {tkImport, tkFnDef})
  result = node

template handleSelectorConcat(parseWithConcat, parseWithoutConcat: untyped) {.dirty.} =
  if unlikely(p.next is tkVarConcat and p.next.line == tk.line):
    # handle selector name declaration
    # prefixed/suffixed by var concat
    walk p
    while p.curr.line == tk.line:
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

proc parseSelectorClass(p: var Parser, scope: ScopeTable = nil,
                    excludeOnly, includeOnly: set[TokenKind] = {}): Node =
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

proc parseCSSProperty(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  ## Parse `key: value` pair as CSS Property
  if likely(p.propsTable.hasKey(p.curr.value)):
    let pName = p.curr
    if p.next is tkColon:
      walk p, 2
      result = newProperty(pName.value)
      while p.curr.line == pName.line:
        # walk along the line and parse values
        case p.curr.kind
        of tkString:
          result.pVal.add(newString(p.curr.value))
          walk p
        of tkInteger:
          result.pVal.add(newInt(p.curr.value))
          walk p
        of tkIdentifier:
          if p.next.kind == tkLPAR and p.next.line == p.curr.line:
            let identToken = p.curr
            let callNode = p.parseCallFnCommand()
            if likely(callNode != nil):
              if likely(callNode.callStackReturnType != ntVoid):
                result.pVal.add(callNode)
              else:
                errorWithArgs(fnReturnVoid, identToken, [callNode.callStackIdent])
        of tkNamedColors, tkColor:
          result.pVal.add(newColor(p.curr.value))
          walk p
        of tkVarCall:
          let varCallNode = p.parseCallCommand(scope)
          if varCallNode != nil:
            result.pVal.add(varCallNode)
        else: break