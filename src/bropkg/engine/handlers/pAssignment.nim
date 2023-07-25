# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

proc parseAnoArray(p: var Parser, scope: var seq[ScopeTable],
      excludeOnly, includeOnly: set[TokenKind] = {}, returnType = ntVoid, isFunctionWrap = false): Node
proc parseAnoObject(p: var Parser, scope: var seq[ScopeTable],
      excludeOnly, includeOnly: set[TokenKind] = {}, returnType = ntVoid, isFunctionWrap = false): Node

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
    var item = p.getAssignableNode(scope)
    if likely(item != nil):
      add anno.itemsVal, item
    else:
      if p.curr is tkLB:
        item = p.parseAnoArray(scope)
        if likely(item != nil):
          add anno.itemsVal, item
        else: return # todo error multi dimensional array
      elif p.curr is tkLC:
        item = p.parseAnoObject(scope)
        if likely(item != nil):
          add anno.itemsVal, item
        else: return # todo error object construction
      else: return # todo error
    if p.curr is tkComma:
      walk p
  if likely(p.curr is tkRB):
    walk p # ]
  return anno

newPrefixProc "parseAnoObject":
  ## parse an anonymous object
  let anno = newObject()
  walk p # {
  while p.curr.kind == tkIdentifier and p.next.kind == tkColon:
    let fName = p.curr.value
    walk p, 2
    if likely(anno.pairsVal.hasKey(fName) == false):
      var item = p.getAssignableNode(scope)
      if likely(item != nil):
        anno.pairsVal[fName] = item
      else:
        if p.curr is tkLB:
          item = p.parseAnoArray(scope)
          if likely(item != nil):
            anno.pairsVal[fName] = item
          else: return # todo error multi dimensional array
        elif p.curr is tkLC:
          item = p.parseAnoObject(scope)
          if likely(item != nil):
            anno.pairsVal[fName] = item
          else: return # todo error object construction
        else: return # todo error
    if p.curr is tkComma:
      walk p # next k/v pair
    # case p.curr.kind:
    # of tkComma:
    #   walk p # next k/v pair
    # of tkRC:
    #   walk p # } end of object
    #   break
    # of tkIdentifier:
    #   if p.curr.line == p.prev.line: return
    # else: return
  if likely(p.curr is tkRC):
    walk p
  return anno

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

proc parseArrayAccessor(p: var Parser, accStorage: Node, scope: var seq[ScopeTable]): Node =
  # Parse an array accessor using `[0][1]`
  walk p # tkLB
  result = newAccessor(ntArray, accStorage)
  if likely(p.curr is tkInteger):  # todo support string type variable calls or functions that returns string
    result.accessorKey = p.curr.value
  else: return nil # invalidArrayAccessorKey
  walk p # tKInteger
  if likely(p.curr is tkRB):
    walk p # tkRB

proc parseObjectAccessor(p: var Parser, accStorage: Node, scope: var seq[ScopeTable]): Node =
  # parse an object accessor using `["myprop"]`
  walk p # tkLB
  result = newAccessor(ntObject, accStorage)
  if likely(p.curr is tkString): # todo support string type variable calls or functions that returns string 
    result.accessorKey = p.curr.value
  else: return nil # invalidObjectAccessorKey
  walk p # tkString
  if likely(p.curr is tkRB):
    walk p # tkRB

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
