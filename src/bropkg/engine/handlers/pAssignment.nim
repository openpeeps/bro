# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

proc parseAnoArray(p: var Parser, scope: var seq[ScopeTable],
                        excludeOnly, includeOnly: set[TokenKind] = {},
                        returnType = ntVoid, isFunctionWrap = false): Node

proc parseAnoObject(p: var Parser, scope: var seq[ScopeTable],
                        excludeOnly, includeOnly: set[TokenKind] = {},
                        returnType = ntVoid, isFunctionWrap = false): Node

proc parseVarDef(p: var Parser, scope: var seq[ScopeTable], ident: TokenTuple): Node =
  # parse a variable definition
  let currentScope = p.getScope(ident.value, scope)
  if currentScope.st != nil:
    let scopedVar = currentScope.st[ident.value]
    if unlikely(scopedVar.varImmutable):
      errorWithArgs(immutableReassign, ident, [ident.value])
    else:
      scopedVar.varOverwrite = true
      p.mVar.delete(hash(scopedVar.varName & $(currentScope.index)))
    return scopedVar
  result = newVariable(ident)
  result.varImmutable = ident.kind == tkConst
  # else:
    # result = newVariableRef(ident)

proc parseVarDefType(p: var Parser, scope: var seq[ScopeTable]): Node =
  # parse a typed variable definition
  discard # todo

proc parseRegularAssignment(p: var Parser, scope: var seq[ScopeTable], ident: TokenTuple): Node =
  var varDef = p.parseVarDef(scope, ident)
  if likely(varDef != nil):
    let varValue = p.getPrefixOrInfix(scope = scope)
    if likely(varValue != nil):
      if unlikely(varDef.varOverwrite):
        let
          varInitType = varDef.varValue.getNodeType()
          varReassignType = varValue.getNodeType
        if unlikely(varInitType != varReassignType):
          errorWithArgs(fnMismatchParam, ident, [varDef.varName, $(varReassignType), $(varInitType)]) 
        if likely(varDef.varRef == false):
          result = deepCopy(varDef)
        else:
          result = varDef
      else:
        result = varDef
      result.varValue = varValue
      result.varType = varValue.getNodeType()
      return # result
    return varDef

proc parseStreamAssignment(p: var Parser, scope: var seq[ScopeTable], ident: TokenTuple): Node =
  # parse JSON/YAML from external sources
  result = p.parseVarDef(scope, ident)
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
  result.varInitType = ntStream

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

proc parseArrayAssignment(p: var Parser, scope: var seq[ScopeTable], ident: TokenTuple): Node =
  ## parse array construction using `[]` and assign to a variable  
  result = p.parseVarDef(scope, ident)
  if unlikely(result == nil): return nil
  result.varValue = p.parseAnoArray(scope)
  result.varType = ntArray
  result.varInitType = ntArray

proc parseObjectAssignment(p: var Parser, scope: var seq[ScopeTable], ident: TokenTuple): Node =
  ## parse object construction using `{}` and assign to a variable 
  result = p.parseVarDef(scope, ident)
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
  let ident = p.curr
  walk p, 2 # =
  result =
    case p.curr.kind:
    of tkLB:              p.parseArrayAssignment(scope, ident)
    of tkLC:              p.parseObjectAssignment(scope, ident)
    of tkJSON:            p.parseStreamAssignment(scope, ident)
    of tkAssignableValue: p.parseRegularAssignment(scope, ident)
    else: nil
  if likely(p.hasErrors == false and result != nil):
    p.stack(result, scope) # add in scope
