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
      if likely(scopedVar != nil):
        if unlikely(scopedVar.varImmutable):
          error(reassignImmutableVar, p.curr)
        else:
          scopedVar.varOverwrite = true
          walk p
        return scopedVar
      else: error(reassignImmutableVar, p.curr)
  result = newVariable(p.curr)
  walk p # $ident

newPrefixProc "parseRegularAssignment":
  result = p.parseVarDef(scope)
  if likely(result != nil):
    let
      tk = p.curr
      varValue = p.getPrefixOrInfix(scope = scope)
    if likely(varValue != nil):
      if likely(result.varOverwrite):
        let
          varInitType = result.varValue.getNodeType()
          varReassignType = varValue.getNodeType
        if unlikely(varInitType != varReassignType):
          errorWithArgs(fnMismatchParam, tk, [result.varName, $(varReassignType), $(varInitType)]) 
      result.varValue = varValue
      result.varType = varValue.nt
      return # result
  return nil

newPrefixProc "parseStreamAssignment":
  # parse JSON/YAML from external sources
  result = p.parseVarDef(scope)
  var fpath: string
  walk p # @json / @yaml
  case p.curr.kind
  of tkString:
    # get file path from string
    fpath = p.curr.value
    walk p
  of tkVarCall:
    # get file path from a variable
    let call = p.parseCallCommand(scope)
    if call != nil:
      fpath = call.varValue.sVal
  else: return nil
  result.varValue = newStream(normalizedPath(p.filePath.parentDir / fpath))

newPrefixProc "parseAnoArray":
  ## parse an anonymous array
  walk p # [
  var anno = newArray()
  while p.curr.kind != tkRB:
    var item = p.getAssignableNode(scope)
    if likely(item != nil):
      if anno.arrayType == ntVoid:
        # set type of array
        anno.arrayType = item.getNodeType
      elif item.getNodeType != anno.arrayType:
        discard # error invalid type, expecting `x`
      add anno.arrayItems, item
    else:
      if p.curr is tkLB:
        item = p.parseAnoArray(scope)
        if likely(item != nil):
          add anno.arrayItems, item
        else: return # todo error multi dimensional array
      elif p.curr is tkLC:
        item = p.parseAnoObject(scope)
        if likely(item != nil):
          add anno.arrayItems, item
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
  while p.curr.value.validIdentifier() and p.next.kind == tkColon:
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
  if likely(p.curr is tkRC):
    walk p
  return anno

newPrefixProc "parseArrayAssignment":
  ## parse array construction using `[]` and assign to a variable  
  result = p.parseVarDef(scope)
  if unlikely(result == nil): return nil
  result.varValue = p.parseAnoArray(scope)
  result.varType = ntArray

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
    result.accessorKey = newInt(p.curr.value)
  else: return nil # invalidArrayAccessorKey
  walk p # tKInteger
  if likely(p.curr is tkRB):
    walk p # tkRB
    return # result
  error(missingRB, p.curr)

proc parseObjectAccessor(p: var Parser, accStorage: Node, scope: var seq[ScopeTable]): Node =
  # parse an object accessor using `["myprop"]`
  walk p # tkLB
  result = newAccessor(ntObject, accStorage)
  if likely(p.curr is tkString):
    result.accessorKey = newString(p.curr.value)
  else:
    return nil # invalidObjectAccessorKey
  walk p # tkString
  if likely(p.curr is tkRB):
    walk p # tkRB
    return # result
  error(missingRB, p.curr)

proc parseCallAccessor(p: var Parser, accStorage: Node, scope: var seq[ScopeTable]): Node =
  walk p # tkLB
  let varCall = p.parseCallCommand(scope)
  if likely(varCall != nil):
    case varCall.callNode.varType
    of ntString:
      result = newAccessor(ntObject, accStorage)
      result.accessorKey = varCall
    of ntInt:
      result = newAccessor(ntArray, accStorage)
      result.accessorKey = varCall
    else:
      return nil
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
  if likely(p.hasErrors == false and result != nil):
    p.stack(result, scope) # add in scope
