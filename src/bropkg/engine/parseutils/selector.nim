proc prefixSelector(node: Node): string =
  result =
    case node.nt
    of NTClassSelector: "." & node.ident
    of NTIDSelector: "#" & node.ident
    else: node.ident

proc checkPseudoSelector(p: var Parser): bool =
  if likely(pseudoTable.hasKey(p.next.value)):
    walk p
    p.curr.col = p.prev.col
    p.curr.pos = p.prev.pos
    return true
  walk p
  error(UnknownPseudoClass, p.prev, p.curr.value)

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
        parentNode.properties[propNode.pName] = propNode
      else: return
    elif p.childOf(this):
      if unlikely(p.curr.kind == tkExtend):
        discard p.parseExtend(scope)
        if p.hasErrors: return # any errors from `parseExtend`
        continue
        # remember last parent when parsing child nodes
      p.lastParent = parentNode
      let node = p.parse(scope, excludeOnly = {tkImport})
      if likely(node != nil):
        case node.nt
        of NTForStmt:
          parentNode.properties[$node.forOid] = node
        of NTCondStmt:
          parentNode.properties[$node.condOid] = node
        of NTCaseStmt:
          parentNode.properties[$node.caseOid] = node
        # of NTPseudoClassSelector:
        #   node.parents = concat(@[parentNode.ident], parentNode.multipleSelectors)
        #   if not parentNode.pseudo.hasKey(node.ident):
        #     parentNode.pseudo[node.ident] = node
        #   else:
        #     for k, v in node.properties:
        #       parentNode.pseudo[node.ident].properties[k] = v
        else:
          case node.nt:
          of NTProperty:          
            if not parentNode.properties.hasKey(node.ident):
              parentNode.properties[node.ident] = node
            else:
              for k, v in node.properties:
                parentNode.properties[node.ident].properties[k] = v
          else:
            if not parentNode.innerNodes.hasKey(node.ident):
              parentNode.innerNodes[node.ident] = node
            else:
              for k, v in node.innerNodes:
                parentNode.innerNodes[node.ident].innerNodes[k] = v
        #   node.parents = concat(@[parentNode.ident], parentNode.multipleSelectors)
      else: break

proc parseSelector(p: var Parser, node: Node, tk: TokenTuple, scope: ScopeTable, toWalk = true): Node =
  if toWalk: walk p
  var multipleSelectors: seq[string]
  while p.curr.kind == tkComma:
    walk p
    if p.curr.kind notin {tkColon, tkIdentifier}:
      var prefixedIdent: string
      if p.curr.kind == tkPseudoClass:
        if not p.checkPseudoSelector():
          return
        prefixedIdent = p.curr.value
      else:
        prefixedIdent = prefixed(p.curr)
      if prefixedIdent != node.ident and prefixedIdent notin multipleSelectors:
        add multipleSelectors, prefixedIdent
        walk p
      else:
        error(DuplicateSelector, p.curr, prefixedIdent)
  node.multipleSelectors = multipleSelectors
  if p.lastParent != nil:
    if p.lastParent.parents.len != 0:
      node.parents = concat(p.lastParent.parents, @[prefixSelector(p.lastParent)])
    else:
      add node.parents, prefixSelector(p.lastParent)
  if p.curr.kind != tkEOF and p.curr.line > tk.line:
    # parse selector properties and child nodes
    p.whileChild(tk, node, scope)
    if unlikely(node.properties.len == 0 and node.extends == false):
      warn(DeclaredEmptySelector, tk, true, node.ident)
    result = node
    result.properties.sort(system.cmp, order = Descending)
    p.lastParent = nil # flush parent
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
    let node = tk.newID(concat = concatNodes)
    p.currentSelector = node
    result = p.parseSelector(node, tk, scope, toWalk = false)
  do:
    let node = tk.newID()
    p.currentSelector = node
    result = p.parseSelector(node, tk, scope)
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
  if p.checkPseudoSelector():
    let tk = p.curr
    result = p.parseSelector(tk.newPseudoClass, tk, scope)