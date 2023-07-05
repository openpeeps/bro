proc parseVarDef(p: var Parser): Node =
  result = newVariable(p.curr)
  walk p # $ident

proc parseRegularAssignment(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  result = p.parseVarDef()
  result.varValue = p.getAssignableNode
  if likely(scope != nil):
    scope[result.varName] = result

proc parseArrayAssignment(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  result = p.parseVarDef()
  result.varValue = newArray()
  walk p # [
  while p.curr.kind in tkAssignableValue:
    add result.varValue.itemsVal, p.getAssignableNode
    case p.curr.kind:
    of tkComma: walk p # parsing next item
    of tkRB:
      walk p # ]
      break
    else: return
  if not scope.isNil():
    scope[result.varName] = result

proc parseStreamAssignment(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  # Parse JSON/YAML from external sources
  var fpath: string
  walk p
  case p.curr.kind
  of tkString:
    # get file path from string
    fpath = p.curr.value
  of tkVarCall:
    # get file path from a variable
    let call = p.parseCallCommand(scope)
    if call != nil:
      fpath = call.varValue.val.sVal
  else: return
  result = newStream(normalizedPath(p.filePath.parentDir / fpath))

proc parseObjectAssignment(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  result = p.parseVarDef()
  result.varValue = newObject()
  walk p # {
  while p.curr.kind == tkIdentifier and p.next.kind == tkColon:
    let fName = p.curr.value
    walk p, 2
    case p.curr.kind:
    of tkAssignableValue:
      if likely(result.varValue.objectFields.hasKey(fName) == false):
        result.varValue.objectFields[fName] = p.getAssignableNode
      case p.curr.kind:
      of tkComma:
        walk p # next k/v pair
      of tkRC:
        walk p # } end of object
        break
      of tkIdentifier:
        if p.curr.line == p.prev.line: return
      else: return
    else: return
  if scope != nil:
    scope[result.varName] = result

proc parseAssignment(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  result =
    case p.next.kind:
    of tkLB:              p.parseArrayAssignment(scope)
    of tkLC:              p.parseObjectAssignment(scope)
    of tkJSON:            p.parseStreamAssignment()
    of tkAssignableValue: p.parseRegularAssignment(scope)
    else: nil

proc parseAnnoArray(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  walk p # {
  let aArray = newArray()
  while p.curr.kind != tkRB:
    let arrItem = p.getAssignableNode()
    if arrItem != nil:
      add aArray.itemsVal, arrItem
    else: return 
  if p.curr.kind == tkRB:
    walk p
    return aArray

proc parseAnnoObject(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  walk p # [
  let aObject = newArray()
  while p.curr.kind != tkRC:
    let arrItem = p.getAssignableNode()
    if arrItem != nil:
      add aObject.varValue.itemsVal, arrItem
    else: return 
  if p.curr.kind == tkRC:
    walk p
    return aObject
