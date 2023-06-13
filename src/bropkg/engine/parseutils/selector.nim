proc parseProperty(p: var Parser, scope: ScopeTable = nil): Node =
  if likely(Properties.hasKey(p.curr.value)):
    let pName = p.curr
    walk p
    if p.curr.kind == tkColon:
      walk p
      result = newProperty(pName.value)
      while p.curr.line == pName.line:
        case p.curr.kind
        of {tkIdentifier, tkColor, tkString, tkCenter} + tkPropsName + tkNamedColors:
          let
            property = Properties[pName.value]
            propValue = p.curr.kind
            checkValue = property.hasStrictValue(p.curr.value)
          if checkValue.exists:
            if checkValue.status in {Unimplemented, Deprecated, Obsolete, NonStandard}:
              warn(UnstablePropertyStatus, p.curr, true,
                      pName.value & ": " & p.curr.value, $checkValue.status)
          result.pVal.add newString(p.curr.value)
          walk p
        of tkInteger:
          result.pVal.add newInt(p.curr.value)
          walk p
        of tkFloat:
          result.pVal.add newFloat(p.curr.value)
          walk p
        of tkVarCall:
          let callNode = p.parseVariableCall(scope)
          if callNode != nil:
            result.pVal.add(deepCopy(callNode))
          else:
            walk p
            return
        of tkVarCallAccessor:
          let callAccessorNode = p.parseVariableAccessor(scope)
          if callAccessorNode != nil:
            result.pVal.add callAccessorNode.val
        else:
          break # TODO error
      case p.curr.kind:
      of tkImportant:
        result.pRule = propRuleImportant
        walk p
      of tkDefault:
        result.pRule = propRuleDefault
        walk p
      else: discard
    else:
      error(MissingAssignmentToken, p.curr)
  else:
    error(InvalidProperty, p.curr, true, p.curr.value)

proc whileChild(p: var Parser, this: TokenTuple, parentNode: Node, scope: ScopeTable) =
  while p.curr.pos > this.pos and p.curr.kind != tkEOF:
    let tk = p.curr
    if p.isPropOf(this):
      let propNode = p.parseProperty(scope)
      if likely(propNode != nil):
        parentNode.props[propNode.pName] = propNode
      else: return
    elif p.childOf(this):
      if unlikely(p.curr.kind == tkExtend):
        discard p.parseExtend(scope)
        if p.hasErrors: return # any errors from `parseExtend`
        continue
      let node = p.parse(scope, excludeOnly = {tkImport})
      if node != nil:
        case node.nt
        of NTForStmt:
          parentNode.props[$node.forOid] = node
        of NTCondStmt:
          parentNode.props[$node.condOid] = node
        of NTCaseStmt:
          parentNode.props[$node.caseOid] = node
        else:
          node.parents = concat(@[parentNode.ident], parentNode.multipleSelectors)
          if not parentNode.props.hasKey(node.ident):
            parentNode.props[node.ident] = node
          else:
            for k, v in node.props.pairs():
              parentNode.props[node.ident].props[k] = v
      else: return

proc parseSelector(p: var Parser, node: Node, tk: TokenTuple, scope: ScopeTable, toWalk = true): Node =
  if toWalk: walk p
  var multipleSelectors: seq[string]
  while p.curr.kind == tkComma:
    walk p
    if p.curr.kind notin {tkColon, tkIdentifier}:
      let prefixedIdent = prefixed(p.curr)
      if prefixedIdent != node.ident and prefixedIdent notin multipleSelectors:
        add multipleSelectors, prefixed(p.curr)
        walk p
      else:
        error(DuplicateSelector, p.curr, prefixedIdent)
  node.multipleSelectors = multipleSelectors
  # parse selector properties or child nodes
  if p.curr.kind != tkEOF and p.curr.line > tk.line:
    p.whileChild(tk, node, scope)
    if unlikely(node.props.len == 0 and node.extends == false):
      warn(DeclaredEmptySelector, tk, true, node.ident)
    result = node
    result.props.sort(system.cmp, order = Descending)
  else:
    if not p.hasErrors:
      error(UnexpectedToken, p.curr, p.curr.value)

template handleSelectorConcat(withConcat, withoutConcat: untyped) =
  if unlikely(p.next.kind == tkVarConcat and p.next.line == tk.line):
    walk p
    while p.curr.line == tk.line:
      # handle selector name + var concatenation
      case p.curr.kind
      of tkVarConcat:
        let concatVarCall = p.parseVariableCall(scope)
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
    withConcat
  else:
    withoutConcat
  p.program.selectors[prefixed(tk)] = result

proc parseClass(p: var Parser, scope: ScopeTable = nil): Node =
  let tk = p.curr
  var concatNodes: seq[Node] # NTVariable
  handleSelectorConcat:
    let node = tk.newClass(concat = concatNodes)
    p.currentSelector = node
    result = p.parseSelector(node, tk, scope, toWalk = false)
  do:
    let node = tk.newClass()
    p.currentSelector = node
    result = p.parseSelector(node, tk, scope)
  p.program.selectors[prefixed(tk)] = result

proc parseID(p: var Parser, scope: ScopeTable = nil): Node =
  let tk = p.curr
  var concatNodes: seq[Node] # NTVariable
  handleSelectorConcat:
    p.currentSelector = tk.newID(concat = concatNodes)
    result = p.parseSelector(p.currentSelector, tk, scope, toWalk = false)
  do:
    p.currentSelector = tk.newID()
    result = p.parseSelector(p.currentSelector, tk, scope)
  p.program.selectors[prefixed(tk)] = result

proc parseNest(p: var Parser, scope: ScopeTable = nil): Node =
  walk p
  case p.curr.kind
  of tkClass, tkID, tkPseudoClass:
    result = p.parseClass(scope)
    result.nested = true
  else:
    error(InvalidNestSelector, p.curr, p.curr.value)

proc parsePseudoNest(p: var Parser, scope: ScopeTable = nil): Node =
  if likely(pseudoTable.hasKey(p.next.value)):
    walk p
    p.curr.col = p.prev.col
    p.curr.pos = p.prev.pos
    let tk = p.curr
    result = p.parseSelector(tk.newPseudoClass, tk, scope)
  else:
    walk p
    error(UnknownPseudoClass, p.prev, p.curr.value)