proc parseVarDef(p: var Parser, scope: ScopeTable): Node =
  if scope != nil:
    if unlikely(scope.hasKey(p.curr.value)):
      let scopedVar = scope[p.curr.value]
      if scopedVar != nil:
        if scopedVar.varImmutable:
          error(reassignImmutableVar, p.curr)
      else:
          error(reassignImmutableVar, p.curr)
  result = newVariable(p.curr)
  walk p # $ident

newPrefixProc "parseRegularAssignment":
  result = p.parseVarDef(scope)
  if unlikely(result == nil): return nil
  result.varValue = p.getAssignableNode

newPrefixProc "parseArrayAssignment":
  result = p.parseVarDef(scope)
  if unlikely(result == nil): return nil
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

newPrefixProc "parseStreamAssignment":
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

newPrefixProc "parseObjectAssignment":
  result = p.parseVarDef(scope)
  if unlikely(result == nil): return nil
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

newPrefixProc "parseAnoArray":
  walk p # [
  let anno = newArray()
  while p.curr.kind != tkRB:
    let arrItem = p.getAssignableNode()
    if arrItem != nil:
      add anno.itemsVal, arrItem
    else: return
    if p.curr.kind == tkComma:
      walk p
    elif p.curr.kind != tkRB:
      return
  if p.curr.kind == tkRB:
    walk p
    return anno

newPrefixProc "parseAnoObject":
  walk p # [
  let anno = newArray()
  while p.curr.kind != tkRC:
    let arrItem = p.getAssignableNode()
    if arrItem != nil:
      add anno.varValue.itemsVal, arrItem
    else: return 
  if p.curr.kind == tkRC:
    walk p
    return anno
