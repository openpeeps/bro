# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

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
    if p.lastParent.nt in {ntProperty, ntTagSelector, ntClassSelector,
                          ntPseudoSelector, ntIDSelector}:
      if p.lastParent.parents.len != 0:
        node.parents = concat(p.lastParent.parents, @[p.lastParent.ident])
      else:
        add node.parents, p.lastParent.ident
      p.lastParent = nil

proc parseSelector(p: var Parser, node: Node, tk: TokenTuple, scope: var seq[ScopeTable], eatIdent = false): Node =
  if eatIdent: walk p # selector ident
  p.parseMultiSelector(node)
  p.parseSelectorStmt((tk, node), scope = scope, excludeOnly = {tkImport, tkFnDef})
  if unlikely(node.properties.len == 0 and node.innerNodes.len == 0):
    warnWithArgs(declaredEmptySelector, tk, [node.ident])
  result = node

newPrefixProc "parseUniversalSelector":
  let tk = p.curr
  var node = newUniversalSelector()
  p.currentSelector = node
  result = p.parseSelector(node, tk, scope, true)

template handleSelectorConcat(parseWithConcat, parseWithoutConcat: untyped) {.dirty.} =
  if p.next is tkLC and p.next.line == tk.line and p.next.wsno == 0:
    walk p
    while p.curr.line == tk.line and p.curr.wsno == 0:
      case p.curr.kind
      of tkLC:
        walk p
        while p.curr isnot tkRC:
          if unlikely(p.curr is tkEOF): return nil # EOF error
          let prefixInfixNode = p.getPrefixOrInfix(scope, includeOnly = {tkInteger, tkBool, tkString, tkVarCall})
          if likely(prefixInfixNode != nil):
            case prefixInfixNode.nt
            of ntInt, ntBool, ntCall, ntInfix, ntMathStmt:
              concatNodes.add(prefixInfixNode)
            else: discard
          else: return nil
      of tkRC:
        walk p
        break
      else: break # should return error?
    parseWithConcat
  else:
    parseWithoutConcat
  p.program.selectors[tk.value] = result

newPrefixProc "parseClass":
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

newPrefixProc "parseSelectorTag":
  let tk = p.curr
  var concatNodes: seq[Node] # ntVariable
  handleSelectorConcat:
    let node = tk.newTag(concat = concatNodes)
    p.currentSelector = node
    result = p.parseSelector(node, tk, scope)
  do:
    let node = tk.newTag()
    p.currentSelector = node
    result = p.parseSelector(node, tk, scope, eatIdent = true)

newPrefixProc "parseSelectorID":
  let tk = p.curr
  var concatNodes: seq[Node] # ntVariable
  handleSelectorConcat:
    let node = tk.newID(concat = concatNodes)
    p.currentSelector = node
    result = p.parseSelector(node, tk, scope)
  do:
    let node = tk.newID()
    p.currentSelector = node
    result = p.parseSelector(node, tk, scope, eatIdent = true)

newPrefixProc "parseProperty":
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
        of tkFloat:
          result.pVal.add(newFloat(p.curr.value))
          walk p
        of tkIdentifier:
          if unlikely(p.next.kind == tkLPAR and p.next.line == p.curr.line):
            let identToken = p.curr
            let callNode = p.parseCallFnCommand(scope)
            if likely(callNode != nil):
              if likely(callNode.stackReturnType != ntVoid):
                result.pVal.add(callNode)
              else:
                errorWithArgs(fnReturnVoid, identToken, [callNode.stackIdentName])
          else:
            result.pVal.add(newString(p.curr.value))
            walk p
        of tkNamedColors, tkColor:
          result.pVal.add(newColor(p.curr.value))
          walk p
        of tkVarCall:
          let varCallNode = p.parseCallCommand(scope)
          if varCallNode != nil:
            result.pVal.add(varCallNode)
            use(varCallNode)
        else: break
    if unlikely(p.curr is tkSemiColon):
      walk p
    return result
  let suggest = toSeq(p.propsTable.itemsWithPrefix(p.curr.value))
  if suggest.len > 0:
    error(invalidProperty, p.curr, true, suggest, $suggestLabel, p.curr.value)
  else:
    if unlikely(p.next is tkColon):
      errorWithArgs(invalidProperty, p.curr, [p.curr.value])