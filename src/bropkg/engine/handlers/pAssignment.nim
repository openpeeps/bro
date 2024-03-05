# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

proc parseAnoArray(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {},
      returnType = ntVoid, isFunctionWrap, isCurlyBlock = false): Node
proc parseAnoObject(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {},
      returnType = ntVoid, isFunctionWrap, isCurlyBlock = false): Node

proc parseArrayAccessor(p: var Parser, accStorage: Node): Node
proc parseDotExpr(p: var Parser, lhs: Node): Node

const IdentCharsWithHyphen = IdentChars + {'-'}
proc isValidIdent(s: string): bool =
  # https://github.com/nim-lang/Nim/blob/devel/lib/pure/strutils.nim#L2404
  if s.len > 0 and s[0] in IdentStartChars:
    for i in 1..s.len-1:
      if s[i] notin IdentCharsWithHyphen: return false
    return true

proc parseVarDef(p: var Parser, ident, vtype: TokenTuple): Node =
  ## Parse a new variable definition
  result = ast.newVariable(ident.value, nil, vtype)
  result.varImmutable = vtype.kind == tkConst

prefixHandle pVarDecl:
  # parse a variable declaration
  let tk = p.curr
  walk p
  expectNot tkCompOperators + tkMathOperators + {tkUnknown}:
    result = ast.newVariable(p.curr.value, nil, tk)
    result.varImmutable = tk is tkConst
    walk p
    case p.curr.kind
    of tkColon:
      discard # todo handle typed var declarations
    of tkAssign:
      walk p
      case p.curr.kind
      of tkAssignable:
        let varValue = p.getPrefixOrInfix()
        notnil varValue:
          result.varValue = varValue
      else: discard
    else: discard

proc parseDotExpr(p: var Parser, lhs: Node): Node =
  # parse dot expression
  result = ast.newNode(ntDotExpr, p.next)
  result.lhs = lhs
  walk p # tkDot
  if p.isFnCall():
    result.rhs = p.pFunctionCall()
  elif p.curr is tkIdentifier:
    result.rhs = ast.newNode(ntIdent, p.curr)
    result.rhs.identName = p.curr.value
    walk p
  else: return nil
  while true:
    case p.curr.kind
    of tkDot:
      if p.curr.line == result.meta[0]:
        result = p.parseDotExpr(result)
      else: break
    of tkLB:
      if p.curr.line == result.meta[0]:
        result = p.parseArrayAccessor(result)
      else: break
    else:
      break # todo handle infix expressions
  # echo result
  
proc parseBracketExpr(p: var Parser, lhs: Node): Node =
  # parse bracket expression
  result = ast.newNode(ntBracketExpr, p.prev)
  walk p # tkLB
  let index = p.getPrefixOrInfix()
  notnil index:
    result.bracketIndex = index
    result.bracketLeft = lhs
  expectWalk tkRB
  while true:
    case p.curr.kind
    of tkLB:
      if p.curr.line == result.meta[0]:
        result = p.parseBracketExpr(result)
      else: break
    of tkDot:
      if p.curr.line == result.meta[0]:
        result = p.parseDotExpr(result)
      else: break
    else:
      break # todo handle infix expressions

proc parseAssignment(p: var Parser, ident: TokenTuple): Node =
  ## parse a new assignment
  # if ident in {tkVar, tkConst}: # var x / const y definition
  #   var varDef = p.parseVarDef(ident, varType)
  #   notnil varDef:
  #     let varValue = p.getPrefixOrInfix()
  #     notnil varValue:
  #       # varDef.varType = varValue.getNodeType
  #       varDef.varValue = varValue
  #       return varDef
  let varValue = p.getPrefixOrInfix()
  notnil varValue:
    result = ast.newAssignment(ident, varValue)

prefixHandle parseAnoArray:
  ## parse an anonymous array
  walk p # [
  var anno = newArray()
  while p.curr.kind != tkRB:
    var item = p.getPrefixOrInfix(includeOnly = tkAssignableValue + {tkLB, tkLC})
    notnil item:
      # if anno.arrayType == ntVoid:
      #   # set type of array
      #   anno.arrayType = item.getNodeType
      # elif item.getNodeType != anno.arrayType:
      #   discard # error invalid type, expecting `x`
      add anno.arrayItems, item
    do:
      if p.curr is tkLB:
        item = p.parseAnoArray()
        notnil item:
          add anno.arrayItems, item
      elif p.curr is tkLC:
        item = p.parseAnoObject()
        notnil item:
          add anno.arrayItems, item
      else: return # todo error
    if p.curr is tkComma:
      walk p
  if likely(p.curr is tkRB):
    walk p # ]
  return anno

prefixHandle parseAnoObject:
  ## parse an anonymous object
  let anno = ast.newObject()
  walk p # {
  while p.curr.value.isValidIdent() and p.next.kind == tkColon:
    let fName = p.curr
    walk p, 2
    if likely(anno.pairsVal.hasKey(fName.value) == false):
      var item = p.getPrefixOrInfix(includeOnly = tkAssignableValue + {tkLB, tkLC})
      notnil item:
        anno.pairsVal[fName.value] = item
      do:
        if p.curr is tkLB:
          item = p.parseAnoArray()
          notnil item:
            anno.pairsVal[fName.value] = item
        elif p.curr is tkLC:
          item = p.parseAnoObject()
          notnil item:
            anno.pairsVal[fName.value] = item
        else: return # todo error
    else:
      errorWithArgs(duplicateObjectKey, fName, [fName.value])
    if p.curr is tkComma:
      walk p # next k/v pair
  if likely(p.curr is tkRC):
    walk p
  return anno

proc parseArrayAssignment(p: var Parser, ident, vtype: TokenTuple): Node =
  ## parse array construction using `[]` and assign to a variable  
  result = p.parseVarDef(ident, vtype)
  if unlikely(result == nil): return nil
  result.varValue = p.parseAnoArray()
  result.varType = ntArray
  result.varInitType = ntArray

proc parseObjectAssignment(p: var Parser, ident, vtype: TokenTuple): Node =
  ## parse object construction using `{}` and assign to a variable 
  result = p.parseVarDef(ident, vtype)
  if unlikely(result == nil): return nil
  result.varValue = p.parseAnoObject()
  result.varType = ntObject
  result.varInitType = ntObject

proc parseArrayAccessor(p: var Parser, accStorage: Node): Node =
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

proc parseObjectAccessor(p: var Parser, accStorage: Node): Node =
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

prefixHandle parseAssignment:
  let ident = p.curr
  walk p
  expectWalk tkAssign
  result =
    case p.curr.kind:
    # of tkLB:              p.parseArrayAssignment(ident)
    # of tkLC:              p.parseObjectAssignment(ident, vartype)
    of tkAssignableValue:
      p.parseAssignment(ident)
    else: nil
