proc parseVarDef(p: var Parser, scope: seq[ScopeTable]): Node =
  if scope.len > 0:
    if unlikely(scope[^1].hasKey(p.curr.value)):
      let scopedVar = scope[^1][p.curr.value]
      if scopedVar != nil:
        if scopedVar.varImmutable:
          error(reassignImmutableVar, p.curr)
      else:
          error(reassignImmutableVar, p.curr)
  result = newVariable(p.curr)
  walk p # $ident

newPrefixProc "parseRegularAssignment":
  ## parse a regular `string`, `int`, `float`, `bool` assignment
  result = p.parseVarDef(scope)
  if unlikely(result == nil): return nil
  result.varValue = p.getAssignableNode(scope)

newPrefixProc "parseStreamAssignment":
  # parse JSON/YAML from external sources
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
      fpath = call.varValue.sVal
  else: return
  result = newStream(normalizedPath(p.filePath.parentDir / fpath))

newPrefixProc "parseAnoArray":
  ## parse an anonymous array
  walk p # [
  let anno = newArray()
  while p.curr.kind != tkRB:
    let arrItem = p.getAssignableNode(scope)
    if arrItem != nil:
      add anno.itemsVal, arrItem
    else: return
    if p.curr.kind == tkComma:
      walk p
    elif p.curr.kind != tkRB:
      return
  if p.curr.kind == tkRB:
    walk p # ]
    return anno
  # todo error

newPrefixProc "parseAnoObject":
  ## parse an anonymous object
  result = newObject()
  walk p # {
  while p.curr.kind == tkIdentifier and p.next.kind == tkColon:
    let fName = p.curr.value
    walk p, 2
    case p.curr.kind:
    of tkAssignableValue:
      if likely(result.objectFields.hasKey(fName) == false):
        result.objectFields[fName] = p.getAssignableNode(scope)
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
  if p.curr is tkRC: walk p

newPrefixProc "parseArrayAssignment":
  ## parse array construction using `[]` and assign to a variable  
  result = p.parseVarDef(scope)
  if unlikely(result == nil): return nil
  result.varValue = p.parseAnoArray(scope)

newPrefixProc "parseObjectAssignment":
  ## parse object construction using `{}` and assign to a variable 
  result = p.parseVarDef(scope)
  if unlikely(result == nil): return nil
  result.varValue = p.parseAnoObject(scope)

newPrefixProc "parseAssignment":
  result =
    case p.next.kind:
    of tkLB:              p.parseArrayAssignment(scope)
    of tkLC:              p.parseObjectAssignment(scope)
    of tkJSON:            p.parseStreamAssignment(scope)
    of tkAssignableValue: p.parseRegularAssignment(scope)
    else: nil
  if not p.hasErrors:
    p.stack(result, scope) # add in scope
