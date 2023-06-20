proc resolveExtended(p: var Parser, pNode: Node) =
  if pNode.ident notin p.currentSelector.extendFrom:
    p.currentSelector.extendFrom.add(pNode.ident)
    pNode.extendBy.add(p.currentSelector.ident)
    for subSelector in pNode.extendFrom:
      let subNode = p.program.selectors[subSelector]
      p.resolveExtended(subNode)
      if p.hasErrors: return
    p.currentSelector.extends = true
  else:
    error(ExtendRedundancyError, p.curr, true, p.currentSelector.ident, pNode.ident)

proc parseExtend(p: var Parser, scope: ScopeTable = nil): Node =
  walk p
  case p.curr.kind
  of tkClass, tkID:
    let pSelectorIdent = p.curr
    if p.program.selectors.hasKey(pSelectorIdent.value):
      let pNode = p.program.selectors[pSelectorIdent.value]
      p.resolveExtended(pNode)
      if not p.hasErrors:
        walk p
      else: return
    else: error(UndeclaredCSSSelector, p.curr, pSelectorIdent.value)
  else: discard # todo
