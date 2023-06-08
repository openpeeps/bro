proc parseVariableCall(p: var Parser, scope: ScopeTable = nil): Node = 
  if scope != nil:
    if scope.hasKey(p.curr.value):
      walk p
      return newCall(scope[p.prev.value])
  if likely(p.memtable.hasKey(p.curr.value)):
    let valNode = p.memtable[p.curr.value]
    valNode.markVarUsed()
    result = newCall(valNode)
    walk p
  else:
    error(UndeclaredVariable, p.curr, "$" & p.curr.value)

proc parseVariableAccessor(p: var Parser, scope: ScopeTable = nil): Node =
  var tkAccessor = p.curr.value.split(".")
  p.curr.value = tkAccessor[0]
  let varIdentStr = "$" & p.curr.value
  tkAccessor.delete(0)
  var key = tkAccessor[0]
  let node = p.parseVariableCall(scope)
  if node.callNode != nil:
    case node.callNode.varValue.nt
    of NTObject:
      if node.callNode.varValue.objectPairs.hasKey(key):
        let valNode = node.callNode.varValue.objectPairs[key]
        case valNode.nt
        of NTVariableValue:
          result = valNode
        else:
          result = newCall(valNode)
      else:
        error(UndefinedPropertyAccessor, p.curr, true, key, varIdentStr)
    of NTJsonValue:
      if node.callNode.varValue.jsonVal.hasKey(key):
        let jsonNode = newJson node.callNode.varValue.jsonVal[key]
        result = newCall(jsonNode)
      else:
        error(UndefinedPropertyAccessor, p.curr, true, key, varIdentStr)
    else:
      error(TryingAccessNonObject, p.curr, true, key, varIdentStr)

proc parseVariable(p: var Parser, scope: ScopeTable = nil): Node =
  ## Parse variable declaration
  let tk = p.curr
  var inArray, inObject: bool
  walk p # tkAssign
  case p.next.kind
  of tkLB:
    # Handle array values
    walk p # tkLB
    inArray = true
  of tkLC:
    # Handle object values
    walk p # tkLC
    inObject = true
  else: discard

  if likely(p.memtable.hasKey(tk.value) == false):
    case p.next.kind
    of tkAssignableValue:
      walk p
      var varNode, valNode: Node
      if p.curr.kind != tkVarCall:
        var varValue: string
        if likely(inArray == false and inObject == false):
          if p.curr.kind == tkBool:
            valNode = newValue(p.getAssignableNode(scope))
          else:
            while p.curr.line == tk.line: # todo check token kind
              if p.curr.kind == tkComment: break
              if p.curr.kind == tkVarCall:
                if p.memtable.hasKey(p.curr.value):
                  discard # todo
                else:
                  error(UndeclaredVariable, p.curr, "$" & p.curr.value)
                  return
              add varValue, spaces(p.curr.wsno)
              add varValue, p.curr.value
              walk p
            valNode = newValue(newString varValue.strip)
        elif inObject:
          # parse object key/value pairs
          valNode = newObject()
          while p.curr.kind == tkIdentifier and p.next.kind == tkColon:
            let key = p.curr.value
            if likely(valNode.objectPairs.hasKey(p.curr.value) == false):
              walk p # tkColon
              assert p.next.kind in tkAssignable
              walk p # any value from tkAssignable
              valNode.objectPairs[key] = newValue(p.getAssignableNode(scope))
              if p.curr.kind == tkComma:
                walk p
              elif p.curr.kind == tkIdentifier and p.curr.line == p.prev.line:
                error(InvalidIndentation, p.curr)
                return
            else:
              error(DuplicateObjectKey, p.curr)
              return
          if p.curr.kind == tkRC:
            walk p
          else:
            error(MissingClosingObjectBody, p.curr)
            return
        else:
          # parse array values
          valNode = newArray()
          while p.curr.kind != tkRB:
            valNode.arrayVal.add(newValue(p.getAssignableNode(scope)))
            if p.curr.kind == tkComma:
              walk p
          if p.curr.kind == tkRB:
            walk p
          else:
            error(MissingClosingBracketArray, p.curr)
            return
        varNode = newVariable(tk.value, valNode, tk)
      else: 
        if p.memtable.hasKey(p.curr.value):
          varNode = deepCopy p.memtable[p.curr.value]
        else:
          error(AssignUndeclaredVar, p.curr, "$" & p.curr.value)
      p.memtable[tk.value] = varNode
      return varNode
    of tkAssignableFn:
      walk p
      if p.next.kind == tkString:
        walk p
        try:
          # temporary
          let filePath = normalizedPath(p.filePath.parentDir / p.curr.value)
          let strContents = readFile(filePath)
          var varNode = newVariable(tk.value, newJson(parseJSON(strContents)), tk)
          p.memtable[tk.value] = varNode
          walk p
          return varNode
        except IOError:
          error(ConfigLoadingError, tk)
        except JsonParsingError as jsonError:
          error(InternalError, tk, true, "JSON parsing error: " & jsonError.msg)
        return
    else: error(UndefinedValueVariable, tk, "$" & tk.value)
  else: error(VariableRedefinition, p.curr)
