# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

proc resolveExtended(p: var Parser, pNode: Node, stylesheet: Stylesheet) =
  if pNode.ident notin p.currentSelector.extendFrom:
    p.currentSelector.extendFrom.add(pNode.ident)
    pNode.extendBy.add(p.currentSelector.ident)
    for subSelector in pNode.extendFrom:
      let subNode = stylesheet.selectors[subSelector]
      p.resolveExtended(subNode, stylesheet)
      if p.hasErrors: return
    p.currentSelector.extends = true
    return
  errorWithArgs(extendRedundancyError, p.curr, [p.currentSelector.ident, pNode.ident])

prefixHandle parseExtend:
  ## Parse a new `@extend` statement and return `Node` representation 
  walk p
  case p.curr.kind
  of tkDot:
    walk p
    p.curr.value = "." & p.curr.value
    p.curr.kind = tkClass
  of tkID:
    discard
  else:
    discard # todo
  
  let ident = p.curr
  if likely(p.program.selectors.hasKey(ident.value)):
    # look into the current stylesheet
    let pNode = p.program.selectors[ident.value]
    p.resolveExtended(pNode, p.program)
    if not p.hasErrors:
      walk p
    else: return
    return Node(nt: ntExtend)

  # otherwise, look into imported stylesheets
  # for (key, index) in p.stylesheets.keys:
  #   p.stylesheets.withFound(key, index):
  #     if value[].selectors.hasKey(ident.value):
  #       let pNode = value[].selectors[ident.value]
  #       p.resolveExtended(pNode, value[])
  #       if not p.hasErrors:
  #         walk p
  #       else: return # error
  #       return Node(nt: ntExtend)
  errorWithArgs(undeclaredCSSSelector, p.curr, [ident.value])