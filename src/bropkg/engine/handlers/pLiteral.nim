proc parseString(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  result = newString(p.curr.value)
  walk p

proc parseInt(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  result = newInt(p.curr.value)
  walk p

proc parseBool(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  result = newBool(p.curr.value)
  walk p

proc parseFloat(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  result = newFloat(p.curr.value)
  walk p