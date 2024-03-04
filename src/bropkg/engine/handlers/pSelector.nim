# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

proc getSelectorName(p: var Parser): string =
  case p.curr.kind
  of tkDot:
    walk p
    result = "." & p.curr.value
  of tkID:
    result = "#" & p.curr.value
  of tkIdentifier:
    result = p.curr.value
  else: discard

proc parseCommonSelectors(p: var Parser, node: Node) =
  var selectors: seq[string]
  while p.curr is tkComma:
    walk p
    if p.curr notin {tkColon #[, tkIdentifier]#}:
      let sName = p.getSelectorName()
      if sName != node.ident and sName notin selectors:
        add selectors, sName
        walk p
      else:
        errorWithArgs(duplicateSelector, p.curr, [sName])
    else: break
  node.multipleSelectors = selectors
  setLen(selectors, 0)
  if p.lastParent != nil:
    if p.lastParent.nt in {ntProperty, ntTagSelector,
        ntClassSelector,ntPseudoSelector, ntIDSelector}:
      if p.lastParent.parents.len != 0:
        node.parents = concat(p.lastParent.parents, @[p.lastParent.ident])
      else:
        add node.parents, p.lastParent.ident
      p.lastParent = nil

template handleSelectorConcat(parseWithConcat, parseWithoutConcat: untyped) {.dirty.} =
  if p.next is tkLC and p.next.line == tk.line and p.next.wsno == 0:
    walk p
    while p.curr.line == tk.line and p.curr.wsno == 0:
      case p.curr.kind
      of tkLC:
        walk p
        while p.curr isnot tkRC:
          if unlikely(p.curr is tkEOF): return nil # EOF error
          let prefixInfixNode = p.getPrefixOrInfix(includeOnly = {tkInteger, tkBool, tkString, tkVarCall})
          if likely(prefixInfixNode != nil):
            case prefixInfixNode.nt
            of ntInt, ntBool, ntIdent, ntInfixExpr, ntInfixMathExpr:
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

proc parseSelector(p: var Parser, node: Node, tk: TokenTuple, eatIdent = false): Node =
  if eatIdent: walk p # selector ident
  p.parseCommonSelectors(node)
  p.parseSelectorStmt((tk, node), excludeOnly = {tkImport, tkFnDef})
  if unlikely(node.properties.len == 0 and node.innerNodes.len == 0):
    if not node.extends:
      warnWithArgs(selectorEmpty, tk, [node.ident])
  result = node

prefixHandle parseUniversalSelector:
  let tk = p.curr
  var node = newUniversalSelector()
  p.currentSelector = node
  result = p.parseSelector(node, tk, true)

template reuseDeclaredSelector() =
  node = p.program.selectors[tk.value]
  p.currentSelector = node
  discard p.parseSelector(node, tk, true)
  p.nilNotError = true

prefixHandle parseClass:
  let tk = p.curr
  var concatNodes: seq[Node] # ntVariable
  var node: Node
  handleSelectorConcat:
    if p.program.selectors.hasKey(tk.value):
      node = p.program.selectors[tk.value]
      discard p.parseSelector(node, tk, true)
      p.nilNotError = true
    else:
      node = tk.newClass(concat = concatNodes)
      p.currentSelector = node
      result = p.parseSelector(node, tk)
      # p.program.selectors[tk.value] = result
  do:
    if p.program.selectors.hasKey(tk.value):
      reuseDeclaredSelector()
    else:
      node = tk.newClass()
      p.currentSelector = node
      result = p.parseSelector(node, tk, eatIdent = true)
      # p.program.selectors[tk.value] = result

prefixHandle parseSelectorTag:
  let tk = p.curr
  var concatNodes: seq[Node] # ntVariable
  var node: Node
  handleSelectorConcat:
    if p.program.selectors.hasKey(tk.value):
      node = p.program.selectors[tk.value]
      discard p.parseSelector(node, tk)
      p.nilNotError = true
    else:
      let node = tk.newTag(concat = concatNodes)
      p.currentSelector = node
      result = p.parseSelector(node, tk)
      # p.program.selectors[tk.value] = result
  do:
    if p.program.selectors.hasKey(tk.value):
      reuseDeclaredSelector()
    else:
      let node = tk.newTag()
      p.currentSelector = node
      result = p.parseSelector(node, tk, eatIdent = true)
      # p.program.selectors[tk.value] = result

prefixHandle parseSelectorID:
  let tk = p.curr
  var concatNodes: seq[Node] # ntVariable
  handleSelectorConcat:
    let node = tk.newID(concat = concatNodes)
    p.currentSelector = node
    result = p.parseSelector(node, tk)
  do:
    let node = tk.newID()
    p.currentSelector = node
    result = p.parseSelector(node, tk, eatIdent = true)

prefixHandle pMultiSelector:
  let tk = p.curr
  walk p
  case p.curr.kind
  of tkDot:
    result = p.pClassSelector()
  of tkID:
    result = p.parseSelectorID()
  of tkIdentifier:
    result = p.parseSelectorTag()
  else: discard
  result.nested = true

prefixHandle parseProperty:
  ## Parse `key: value` pair as CSS Property
  if likely(p.propsTable.hasKey(p.curr.value)):
    let pName = p.curr
    var pColon: TokenTuple
    var shared: seq[Node]
    if p.next in {tkColon, tkComma}:
      walk p
      pColon = p.next
      result = newProperty(pName.value)
      if unlikely(p.curr is tkComma):
        while p.curr is tkComma:
          walk p
          if likely(p.propsTable.hasKey(p.curr.value)):
            shared.add(newProperty(p.curr.value))
            walk p
          else: return nil
        if likely(p.curr is tkColon):
          pColon = p.curr
          walk p
        else: return nil
      elif p.curr is tkColon:
        pColon = p.curr
        walk p
      else: return nil
      while p.curr.line == pColon.line:
        # walk along the line and parse values
        case p.curr.kind
        of tkString:
          result.pVal.add(newString(p.curr.value))
          walk p
        of tkInteger:
          add result.pVal, p.parseInt()
          # result.pVal.add(newInt(p.curr.value))
          # walk p
        of tkFloat:
          add result.pVal, p.parseFloat()
        of tkIdentifier:
          if unlikely(p.next.kind == tkLP and p.next.line == p.curr.line):
            let identToken = p.curr
            let callNode = p.pFunctionCall()
            if likely(callNode != nil):
              result.pVal.add(callNode)
              # errorWithArgs(fnReturnVoid, identToken, [callNode.stackIdentName])
          else:
            result.pVal.add(newString(p.curr.value))
            walk p
        of tkNamedColors, tkColor:
          add result.pVal, p.parseColor()
        of tkVarCall:
          let varCallNode = p.pIdentCall()
          if varCallNode != nil:
            result.pVal.add(varCallNode)
            use(varCallNode)
        else: break
      if unlikely(result.pVal.len == 0):
        errorWithArgs(propMissingCSSValue, pName, [pName.value])
    if unlikely(p.curr is tkSemiColon): walk p
    result.pShared = shared
  # if p.next is tkColon:
  #   let suggest = toSeq(p.propsTable.itemsWithPrefix(p.curr.value))
  #   if suggest.len > 0:
  #       error(invalidProperty, p.curr, true, suggest, $suggestLabel, p.curr.value)
  #   else:
  #     errorWithArgs(invalidProperty, p.curr, [p.curr.value])

prefixHandle parseThis:
  ## parse `this` symbol inside a selector block
  if p.next.kind == tkDot:
    walk p
    let dotExpr = p.pClassSelector()
    echo dotExpr
