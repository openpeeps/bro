# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import pkg/[jsony, chroma]
import std/[tables, strutils, macros, sequtils, json,
  math, oids, hashes, terminal, threadpool, enumutils]
import ./ast, ./sourcemap, ./stdlib, ./logging

type
  Warning* = tuple[msg: string, line, col: int]
  Compiler* = object
    css*, deferred, deferredProps: string
    stylesheet: Stylesheet
    sourceMap: SourceInfo
    minify: bool
    strCL: string = "{"
    strCR: string = "}"
    strNL: string = "\n"
    stylesheets: Stylesheets
    # localScope: seq[ScopeTable]
    globalScope: ScopeTable
    warnings*: seq[Warning]
    when compileOption("app", "console"):
      logger*: Logger
  
  FunctionHandler = proc(c: var Compiler, node: Node, scope: var seq[ScopeTable], parent: Node = nil): Node
  CallableFn = proc(c: Compiler, scope: var seq[ScopeTable], fnNode: Node, args: seq[Node]): Node {.nimcall.}

  BroAssert* = object of CatchableError
  CompilerError = object of CatchableError

#
# Forward declaration
#
proc walkNodes(c: var Compiler, node: Node, scope: var seq[ScopeTable]): Node {.discardable.}
proc walkSubNodes(c: var Compiler, node, parent: Node,
      scopetables: var seq[ScopeTable], len: int, ix: var int)

proc getValue(c: var Compiler, node: Node,
    scopetables: var seq[ScopeTable], printError = true,
    toRootvalue = true): Node

proc typeCheck(c: var Compiler, x, node: Node): bool
proc typeCheck(c: var Compiler, node: Node, expect: NodeType): bool

proc dotEvaluator(c: var Compiler, node: Node, scopetables: var seq[ScopeTable]): Node
proc bracketEvaluator(c: var Compiler, node: Node, scopetables: var seq[ScopeTable]): Node

proc infixEvaluator(c: var Compiler, lhs, rhs: Node,
    op: InfixOp, scopetables: var seq[ScopeTable]): bool

proc mathInfixEvaluator(c: var Compiler, lhs, rhs: Node,
    op: MathOp, scopetables: var seq[ScopeTable]): Node

proc getSelectorGroup(c: var Compiler, node: Node,
  scopetables: var seq[ScopeTable], parent: Node = nil): string

proc functionCall(c: var Compiler, node: Node,
      scopetables: var seq[ScopeTable], parent: Node = nil): Node {.discardable.}

#
# template errors
#
template printTypeMismatch {.dirty.} =
  compileErrorWithArgs(typeMismatch, [$(rn.nt), $(ln.nt)], rn.meta)

template exploreAst =
    var info =
      case node.nt
      of ntVariable:
        if node.varImmutable: "ConstDef"
        else: "VarDef"
      else: $(node.nt)
    add info, "[$1:$2]" % [$(node.meta.line), $(node.meta.pos)]
    # echo indent(info, node.meta.pos)

macro newHandler(name, body: untyped) =
  newProc(name,
    [
      # newEmptyNode(), # return type
      ident("Node"),
      nnkIdentDefs.newTree(
        ident("c"),
        nnkVarTy.newTree(ident("Compiler")),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident("node"),
        ident("Node"),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident("scopetables"),
        nnkVarTy.newTree(nnkBracketExpr.newTree(ident("seq"), ident("ScopeTable"))),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident("parent"),
        ident("Node"),
        newNilLit()
      ),
    ],
    body,
    pragmas = nnkPragma.newTree(
      ident("discardable")
    )
  )

#
# Type Checker
#
proc typeCheck(c: var Compiler, x, node: Node): bool =
  if unlikely(x.nt != node.nt):
    case x.nt
    of ntInfixMathExpr, ntInt, ntFloat:
      return node.nt in {ntInt, ntFloat, ntInfixMathExpr} 
    else: discard
    compileErrorWithArgs(typeMismatch, [$(node.nt), $(x.nt)])
  result = true

proc typeCheck(c: var Compiler, node: Node, expect: NodeType): bool =
  if unlikely(node.nt != expect):
    compileErrorWithArgs(typeMismatch, [$(node.nt), $(expect)])
  result = true

#
# Scope API
# todo rework scope tables
# lookout for scoped callables using the address
# cast[int](node.addr).toHex
#
proc globalScope(c: var Compiler, key: string, node: Node) =
  # Add `node` to global scope
  c.globalScope[key] = node

proc `+=`(scope: ScopeTable, key: string, node: Node) =
  # Add `node` to current `scope` 
  scope[key] = node

proc stack(c: var Compiler, key: string, node: Node,
    scopetables: var seq[ScopeTable]) =
  # Add `node` to either local or global scope
  case node.nt
  of ntVariable:
    if scopetables.len > 0:
      scopetables[^1]["$" & node.varName] = node
    else:
      c.globalScope["$" & node.varName] = node
  of ntFunction:
    if node.fnSource != "std/system":
      if scopetables.len > 0:
        scopetables[^1][node.fnName] = node
      else:
        c.globalScope[node.fnName] = node
    else:
      c.stylesheet.exports[node.fnName] = node
  else: discard

proc getCurrentScope(c: var Compiler,
    scopetables: var seq[ScopeTable]): ScopeTable =
  # Returns the current `ScopeTable`. When not found,
  # returns the `globalScope` ScopeTable
  if scopetables.len > 0:
    return scopetables[^1] # the last scope
  return c.globalScope

proc getScope(c: var Compiler, key: string,
    scopetables: var seq[ScopeTable]
  ): tuple[scopeTable: ScopeTable, index: int] =
  # Walks (bottom-top) through available `scopetables`, and finds
  # the closest `ScopeTable` that contains a node for given `key`.
  # If found returns the ScopeTable followed by index (position).
  if scopetables.len > 0:
    for i in countdown(scopetables.high, scopetables.low):
      if scopetables[i].hasKey(key):
        return (scopetables[i], i)
  if c.globalScope.hasKey(key):
    return (c.globalScope, 0)

proc inScope(c: Compiler, key: string, scopetables: var seq[ScopeTable]): bool =
  # Performs a quick search in the current `ScopeTable`
  if scopetables.len > 0:
    result = scopetables[^1].hasKey(key)
  if not result:
    return c.globalScope.hasKey(key)

proc fromScope(c: var Compiler, key: string,
    scopetables: var seq[ScopeTable]): Node =
  # Retrieves a node by `key` from `scopetables`
  let some = c.getScope(key, scopetables)
  if some.scopeTable != nil:
    return some.scopeTable[key]

proc newScope(scopetables: var seq[ScopeTable]) {.inline.} =
  ## Create a new Scope
  scopetables.add(ScopeTable())

proc clearScope(scopetables: var seq[ScopeTable]) {.inline.} =
  ## Clears the current (latest) ScopeTable
  scopetables.delete(scopetables.high)

template notnil(x, body) =
  if likely(x != nil):
    body

template notnil(x, body, elseBody) =
  if likely(x != nil):
    body
  else:
    elseBody

#
# AST Modifiers
#
proc dumpHook*(s: var string, v: seq[Node])         # dump array storage
proc dumpHook*(s: var string, v: CritBitTree[Node]) # dump object storage

proc dumpHook*(s: var string, v: Node) =
  ## Dumps `v` node to stringified JSON using `pkg/jsony`
  case v.nt
  of ntString: s.add("\"" & $v.sVal & "\"")
  of ntFloat:  s.add($v.fVal)
  of ntInt:    s.add($v.iVal)
  of ntBool:   s.add($v.bVal)
  of ntObject: s.dumpHook(v.pairsVal) # rename field to objectItems
  of ntArray:  s.dumpHook(v.arrayItems)
  of ntStream: s.dumpHook(v.streamContent)
  else: discard

proc dumpHook*(s: var string, v: seq[Node]) =
  s.add("[")
  if v.len > 0:
    s.dumpHook(v[0])
    for i in 1 .. v.high:
      s.add(",")
      s.dumpHook(v[i])
  s.add("]")

proc dumpHook*(s: var string, v: CritBitTree[Node]) =
  var i = 0
  let len = v.len - 1
  s.add("{")
  for k, node in v:
    s.add("\"" & k & "\":")
    s.dumpHook(node)
    if i < len:
      s.add(",")
    inc i
  s.add("}")

proc sizeToString(v: Node): string =
  case v.sizeVal.nt
  of ntInt:   $(v.sizeVal.iVal) & $(v.sizeUnit)
  of ntFloat: $(v.sizeVal.fVal) & $(v.sizeUnit)
  else: "" # todo support for callables

proc toString(node: JsonNode, escape = false): string =
  result =
    case node.kind
    of JString: node.str
    of JInt:    $node.num
    of JFloat:  $node.fnum
    of JBool:   $node.bval
    of JObject, JArray: $(node)
    else: "null"

proc toString(node: Node): string =
  result =
    case node.nt
    of ntString:
      node.sVal
    of ntInt:   $(node.iVal)
    of ntFloat: $(node.fVal)
    of ntBool:  $(node.bVal)
    of ntSize:  sizeToString(node)
    of ntColor: toHtmlHex(node.cValue)
    of ntArray:
      fromJson(jsony.toJson(node.arrayItems)).pretty
    of ntObject:
      fromJson(jsony.toJson(node.pairsVal)).pretty
    of ntStream:
      node.streamContent.toString
      # fromJson(jsony.toJson(node.streamContent)).pretty
    else: ""

template print(v: Node) =
  block:
    let meta = " ($1:$2) " % [$v.meta[0], $v.meta[2]]
    stdout.styledWriteLine(
      fgGreen, "Debug",
      fgDefault, meta,
      fgMagenta, $(v.nt),
      fgDefault, "\n" & v.toString()
    )

proc getValues(c: var Compiler, node: Node,
    scopetables: var seq[ScopeTable]): seq[Node] =
  add result, c.getValue(node.infixLeft, scopetables)
  add result, c.getValue(node.infixRight, scopetables)

proc getValue(c: var Compiler, node: Node,
    scopetables: var seq[ScopeTable],
    printError = true, toRootvalue = true): Node =
  notnil node:
    case node.nt
    of ntString, ntInt, ntFloat, ntBool,
       ntColor, ntStream, ntArray, ntObject:
      result = node
    of ntIdent:
      let some = c.getScope(node.identName, scopetables)
      notnil some.scopeTable:
        return some.scopeTable[node.identName].varvalue
      if printError:
        compileErrorWithArgs(varUndeclared, [node.identName])
    of ntInfixMathExpr:
      result = c.mathInfixEvaluator(node.mathLeft, node.mathRight, node.mathInfixOp, scopetables)
    of ntInfixExpr:
      var x = c.infixEvaluator(node.infixLeft, node.infixRight, node.infixOp, scopetables)
      result = ast.newNode(ntBool)
      result.bVal = x
    of ntDotExpr:
      result = c.dotEvaluator(node, scopetables)
    of ntSize:
      case toRootvalue:
      of true:
        result = node.sizeVal
      else:
        result = node
    of ntCallFunction:
      result = c.functionCall(node, scopetables)
    of ntBracketExpr:
      result = c.bracketEvaluator(node, scopetables)
    else: discard

# math evaluator branches
template calcInfixNest() {.dirty.} =
  let rhs = c.mathInfixEvaluator(rhs.mathLeft, rhs.mathRight, rhs.mathInfixOp, scopetables)
  notnil rhs:
    return c.mathInfixEvaluator(lhs, rhs, op, scopetables)

proc mathInfixEvaluator(c: var Compiler, lhs, rhs: Node,
    op: MathOp, scopetables: var seq[ScopeTable]): Node =
  ## todo unit conversion
  ## based on body font-size
  ## default font-size in browsers: 1em = 16px
  case op
  of mPlus:
    var ln = c.getValue(lhs, scopetables)
    let rn = c.getValue(rhs, scopetables)
    case ln.nt
    of ntInt:
      case rn.nt
      of ntInt:
        result = ast.newNode(ntInt)
        result.iVal = ln.iVal + rn.iVal
      of ntFloat:
        result = ast.newNode(ntFloat)
        result.fVal = toFloat(ln.iVal) + rn.fVal
      else: discard
    of ntFloat:
      case rn.nt
      of ntFloat:
        result = ast.newNode(ntFloat)
        result.fVal = ln.fVal + rn.fVal
      of ntInt:
        result = ast.newNode(ntInt)
        result.fVal = ln.fVal + toFloat(rn.iVal)
      else: discard
    else: discard
    case lhs.nt
    of ntSize:
      result = ast.newSize(result, lhs.sizeUnit)
    else: discard
  else: discard

proc walkAccessorStorage(c: var Compiler,
    lhs, rhs: Node, scopetables: var seq[ScopeTable]): Node =
  case lhs.nt
  of ntIdent:
    let lhs = c.getValue(lhs, scopetables)
    notnil lhs:
      case rhs.nt
      of ntCallFunction:
        rhs.fnCallArgs.insert(lhs, 0)
        result = c.functionCall(rhs, scopetables)
        rhs.fnCallArgs.del(0)
      else:
        result = c.walkAccessorStorage(lhs, rhs, scopetables)
  of ntObject:
    case rhs.nt
    of ntIdent:
      try:
        result = lhs.pairsVal[rhs.identName]
      except KeyError:
        compileErrorWithArgs(undeclaredField, [rhs.identName], rhs.meta)
    else: compileErrorWithArgs(invalidAccessorStorage, [rhs.toString, $lhs.nt], rhs.meta)
  of ntStream:
    case rhs.nt
    of ntIdent:
      try:
        result = ast.newStream(lhs.streamContent[rhs.identName])
      except KeyError:
        compileErrorWithArgs(undeclaredField, [rhs.identName], rhs.meta)
    else: compileErrorWithArgs(invalidAccessorStorage, [rhs.toString, $lhs.nt], rhs.meta)
  of ntArray:
    case rhs.nt
    of ntInt:
      try:
        result = lhs.arrayItems[rhs.iVal]
      except Defect:
        compileErrorWithArgs(indexDefect, [$(rhs.iVal), "0.." & $(lhs.arrayItems.high)], lhs.meta)
    else: compileErrorWithArgs(invalidAccessorStorage, [rhs.toString, $lhs.nt], rhs.meta)
  of ntBracketExpr:
    let lhs = c.bracketEvaluator(lhs, scopetables)
    notnil lhs:
      return c.walkAccessorStorage(lhs, rhs, scopetables)
  of ntDotExpr:
    let lhs = c.dotEvaluator(lhs, scopetables)
    notnil lhs:
      case rhs.nt
      of ntCallFunction:
        rhs.fnCallArgs.insert(lhs, 0)
        result = c.functionCall(rhs, scopetables)
        rhs.fnCallArgs.del(0)
      else:
        return c.walkAccessorStorage(lhs, rhs, scopetables)
  of ntCallFunction:
    case rhs.nt
    of ntCallFunction:
      let lhs = c.functionCall(lhs, scopetables)
      notnil lhs:
        rhs.fnCallArgs.insert(lhs, 0)
        result = c.functionCall(rhs, scopetables)
        rhs.fnCallArgs.del(0)
    else:
      let lhs = c.functionCall(lhs, scopetables)
      notnil lhs:
        return c.walkAccessorStorage(lhs, rhs, scopetables)
  # of ntString, ntInt, ntFloat:
  #   case rhs.nt
  #   of ntDotExpr:
  #     # rhs.fnCallArgs.insert(lhs, 0)
  #     # result = c.functionCall(rhs, scopetables)
  #     # rhs.fnCallArgs.del(0)
  #   else: discard # error? invalid dot expression
  else: discard # todo

proc dotEvaluator(c: var Compiler, node: Node,
    scopetables: var seq[ScopeTable]): Node =
  # evaluates dot expressions
  result = c.walkAccessorStorage(node.lhs, node.rhs, scopetables)

proc bracketEvaluator(c: var Compiler, node: Node, scopetables: var seq[ScopeTable]): Node =
  let index = c.getValue(node.bracketIndex, scopetables)
  notnil index:
    result = c.walkAccessorStorage(node.bracketLeft, index, scopetables)

proc infixEvaluator(c: var Compiler, lhs, rhs: Node,
    op: InfixOp, scopetables: var seq[ScopeTable]): bool =
  # evaluates comparison expressions
  if unlikely(lhs == nil or rhs == nil): return
  let
    ln = c.getValue(lhs, scopetables)
    rn = c.getValue(rhs, scopetables)
  if unlikely(ln == nil or rn == nil): return
  case op
  of EQ:
    case ln.nt
    of ntInt:
      case rn.nt
      of ntInt:
        if lhs.nt == ntSize and rhs.nt == ntSize:
          return ln.iVal == rn.iVal and lhs.sizeUnit == rhs.sizeUnit
        result = ln.iVal == rn.iVal
      of ntFloat:
        if lhs.nt == ntSize and rhs.nt == ntSize:
          return toFloat(ln.iVal) == rn.fVal and lhs.sizeUnit == rhs.sizeUnit
        result = toFloat(ln.iVal) == rn.fVal
      else: printTypeMismatch
    of ntFloat:
      case rn.nt
      of ntInt:
        if lhs.nt == ntSize and rhs.nt == ntSize:
          return ln.fVal == toFloat(rn.iVal) and lhs.sizeUnit == rhs.sizeUnit
        result = ln.fVal == toFloat(rn.iVal)
      of ntFloat:
        if lhs.nt == ntSize and rhs.nt == ntSize:
          return ln.fVal == rn.fVal and lhs.sizeUnit == rhs.sizeUnit
        result = ln.fVal == rn.fVal
      else: printTypeMismatch
    of ntColor:
      case rn.nt
      of ntColor:
        result = ln.cValue == rn.cValue
      else: printTypeMismatch
    of ntBool:
      case rn.nt
      of ntBool:
        result = ln.bVal == rn.bVal
      else: printTypeMismatch
    of ntString:
      case rn.nt:
      of ntString:
        result = ln.sVal == rn.sVal
      else: printTypeMismatch
    else: discard
  of NE:
    case ln.nt
    of ntInt:
      case rn.nt
      of ntInt:
        result = ln.iVal != rn.iVal
      of ntFloat:
        result = toFloat(ln.iVal) != rn.fVal
      else: printTypeMismatch
    of ntFloat:
      case rn.nt
      of ntInt:
        result = toFloat(ln.iVal) != rn.fVal
      of ntFloat:
        result = ln.fVal != rn.fVal
      else: printTypeMismatch
    else: discard
  of GT:
    case lhs.nt:
    of ntInt:
      case rhs.nt
      of ntInt:
        result = lhs.iVal > rhs.iVal
      of ntFloat:
        result = toFloat(lhs.iVal) > rhs.fVal
      else: printTypeMismatch
    of ntFloat:
      case rhs.nt
      of ntFloat:
        result = lhs.fVal > rhs.fVal
      of ntInt:
        result = lhs.fVal > toFloat(rhs.iVal)
      else: printTypeMismatch
    of ntIdent:
      let lhs = c.getValue(lhs, scopetables)
      if likely(lhs != nil):
        return c.infixEvaluator(lhs, rhs, op, scopetables)
    else: discard
  of GTE:
    case lhs.nt:
    of ntInt:
      case rhs.nt
      of ntInt:
        result = lhs.iVal >= rhs.iVal
      of ntFloat:
        result = toFloat(lhs.iVal) >= rhs.fVal
      else: printTypeMismatch
    of ntFloat:
      case rhs.nt
      of ntFloat:
        result = lhs.fVal >= rhs.fVal
      of ntInt:
        result = lhs.fVal >= toFloat(rhs.iVal)
      else: printTypeMismatch
    of ntIdent:
      let lhs = c.getValue(lhs, scopetables)
      if likely(lhs != nil):
        return c.infixEvaluator(lhs, rhs, op, scopetables)
    else: discard
  of LT:
    case lhs.nt:
    of ntInt:
      case rhs.nt
      of ntInt:
        result = lhs.iVal < rhs.iVal
      of ntFloat:
        result = toFloat(lhs.iVal) < rhs.fVal
      else: printTypeMismatch
    of ntFloat:
      case rhs.nt
      of ntFloat:
        result = lhs.fVal < rhs.fVal
      of ntInt:
        result = lhs.fVal < toFloat(rhs.iVal)
      else: printTypeMismatch
    of ntIdent:
      let lhs = c.getValue(lhs, scopetables)
      if likely(lhs != nil):
        return c.infixEvaluator(lhs, rhs, op, scopetables)
    else: discard
  of LTE:
    case lhs.nt:
    of ntInt:
      case rhs.nt
      of ntInt:
        result = lhs.iVal <= rhs.iVal
      of ntFloat:
        result = toFloat(lhs.iVal) <= rhs.fVal
      else: printTypeMismatch
    of ntFloat:
      case rhs.nt
      of ntFloat:
        result = lhs.fVal <= rhs.fVal
      of ntInt:
        result = lhs.fVal <= toFloat(rhs.iVal)
      else: printTypeMismatch
    of ntIdent:
      let lhs = c.getValue(lhs, scopetables)
      if likely(lhs != nil):
        return c.infixEvaluator(lhs, rhs, op, scopetables)
    else: discard
  of AND:
    case lhs.nt
    of ntInfixExpr:
      result = c.infixEvaluator(lhs.infixLeft, lhs.infixRight, lhs.infixOp, scopetables)
      if result:
        case rhs.nt:
        of ntInfixExpr:
          return c.infixEvaluator(rhs.infixLeft, rhs.infixRight, rhs.infixOp, scopetables)
        else: discard # todo
    else: discard
  of OR:
    case lhs.nt
    of ntInfixExpr:
      result = c.infixEvaluator(lhs.infixLeft, lhs.infixRight, lhs.infixOp, scopetables)
      if not result:
        case rhs.nt:
        of ntInfixExpr:
          return c.infixEvaluator(rhs.infixLeft, rhs.infixRight, rhs.infixOp, scopetables)
        else: discard # todo
    else: discard
  else: discard

#
# Load all handlers
#
newHandler walkInnerStmtList:
  let len = node.stmtList.len
  var ix = 1
  for inner in node.stmtList:
    c.walkSubNodes(inner, parent, scopetables, len, ix)

newHandler walkStmtList:
  for inner in node.stmtList:
    c.walkNodes(inner, scopetables)

newHandler varDecl:
  # handle variable declarations
  if likely(not c.inScope("$" & node.varName, scopetables)):
    let x = c.getValue(node.varValue, scopetables)
    notnil x:
      case node.varValue.nt
      of ntInfixMathExpr:
        node.varValue = x
      of ntIdent:
        node.varValue = deepCopy(x)
      of ntCallFunction:
        node.varValue = x
      of ntDotExpr:
        node.varValue = x
      else: discard
      c.stack(node.varName, node, scopetables)
  else: compileErrorWithArgs(varRedefine, [node.varName])

newHandler varAssign:
  # handle variable assignments
  let some = c.getScope(node.asgnIdent, scopetables)
  notnil some.scopeTable:
    let varNode = some.scopeTable[node.asgnIdent]
    let newValue = c.getValue(node.asgnValue, scopetables)
    notnil newValue:
      if likely(c.typeCheck(varNode.varValue, newValue)):
        if likely(not varNode.varImmutable):
          varNode.varValue = newValue
        else:
          compileErrorWithArgs(varImmutable, [varNode.varName])

let rhsDefaultBool = ast.newNode(ntBool)
rhsDefaultBool.bVal = true

template evalBranch(branch: Node, body: untyped) =
  case branch.nt
  of ntInfixExpr:
    if c.infixEvaluator(branch.infixLeft, branch.infixRight,
        branch.infixOp, scopetables):
      newScope(scopetables)
      body
      clearScope(scopetables)
      return # condition is thruty
  of ntIdent:
    if c.infixEvaluator(branch, rhsDefaultBool, EQ, scopetables):
      newScope(scopetables)
      body
      clearScope(scopetables)
      return # condition is thruty
  of ntDotExpr:
    let x = c.dotEvaluator(branch, scopetables)
    notnil x:
      if c.infixEvaluator(x, rhsDefaultBool, EQ, scopetables):
        newScope(scopetables)
        body
        clearScope(scopetables)
        return # condition is thruty
  else: discard

newHandler condDecl:
  # handle conditional statements
  evalBranch node.condIfBranch.expr:
    c.walkNodes(node.condIfBranch.body, scopetables)
  if node.condElifBranch.len > 0:
    # handle `elif` branches
    for elifbranch in node.condElifBranch:
      evalBranch elifBranch.expr:
        c.walkNodes(elifbranch.body, scopetables)
  notnil node.condElseBranch:
    # handle `else` branch
    c.walkNodes(node.condElseBranch, scopetables)

newHandler innerCondDecl:
  # handles conditional statements in selector nests
  evalBranch node.condIfBranch.expr:
    c.walkInnerStmtList(node.condIfBranch.body, scopetables, parent)
  if node.condElifBranch.len > 0:
    # handle `elif` branches
    for elifbranch in node.condElifBranch:
      evalBranch elifBranch.expr:
        c.walkInnerStmtList(elifbranch.body, scopetables, parent)
  notnil node.condElseBranch:
    # handle `else` branch
    c.walkInnerStmtList(node.condElseBranch, scopetables, parent)

template loopEvaluator(kv: (Node, Node), items: Node) =
  case items.nt
  of ntArray:
    if kv[1] == nil:
      case kv[0].nt
      of ntVariable:
        for x in items.arrayItems:
          newScope(scopetables)
          kv[0].varValue = x
          c.varDecl(kv[0], scopetables)
          c.walkNodes(node.loopBody, scopetables)
          clearScope(scopetables)
          kv[0].varValue = nil
      else: discard
  else: discard

newHandler loopEval:
  # handles iterations
  case node.loopItems.nt
  of ntIdent:
    let some = c.getScope(node.loopItems.identName, scopetables)
    notnil some.scopeTable:
      let items = some.scopeTable[node.loopItems.identName]
      loopEvaluator(node.loopItem, items.varValue)
    do: compileErrorWithArgs(varUndeclared, [node.loopItems.identName])
  of ntDotExpr:
    let items = c.dotEvaluator(node.loopItems, scopetables)
    notnil items:
      loopEvaluator(node.loopItem, items)
    do:
      compileErrorWithArgs(varUndeclared, [node.loopItems.lhs.identName])
  of ntArray:
    loopEvaluator(node.loopItem, node.loopItems)
  of ntBracketExpr:
    let items = c.bracketEvaluator(node.loopItems, scopetables)
    loopEvaluator(node.loopItem, items)
  of ntCallFunction:
    let items = c.functionCall(node.loopItems, scopetables)
    loopEvaluator(node.loopItem, items)
  else: compileErrorWithArgs(invalidIterator)

newHandler commandEval:
  # evaluates a command
  if c.minify: return # disable debugging when enabled minify
  let val = c.getvalue(node.cmdValue, scopetables)
  notnil val:
    case node.cmdIdent
    of cmdEcho:
      val.meta = node.cmdValue.meta
      print val
    else: discard

newHandler functionCall:
  # handles function calls
  let some = c.getScope(node.fnCallIdentName, scopetables)
  notnil some.scopeTable:
    let fnNode = some.scopeTable[node.fnCallIdentName]
    if fnNode.fnParams.len == node.fnCallArgs.len:
      if fnNode.fnFwdDecl:
        let params = fnNode.fnParams.keys.toSeq()
        var args: seq[stdlib.Arg]
        for i in 0..node.fnCallArgs.high:
          try:
            let param = fnNode.fnParams[params[i]]
            let argValue = c.getValue(node.fnCallArgs[i], scopetables, toRootvalue = false)
            if c.typeCheck(argValue, param[1]):
              add args, (param[0][1..^1], argValue)
            else: return # typeCheck returns `typeMismatch`
          except Defect:
            compileErrorWithArgs(fnExtraArg, [node.fnCallIdentName, $(params.len), $(node.fnCallArgs.len)])
        try:
          return stdlib.call(fnNode.fnSource, fnNode.fnName, args)
        except SystemModule as e:
          compileErrorWithArgs(internalError, [e.msg, fnNode.fnSource, fnNode.fnName], node.meta)
    else: 
      # todo check optional args
      echo "?"
  do:
    compileErrorWithArgs(fnUndeclared, [node.fnCallIdentName], node.meta)

newHandler importModule:
  if likely(c.stylesheets.len > 0):
    for path in node.modules:
      # change logger's file path during iteration
      c.logger.filePath = c.stylesheets[path].sourcePath
      for childNode in c.stylesheets[path].nodes:
        c.walkNodes(childNode, scopetables)
    c.logger.filePath = c.stylesheet.sourcePath # back to main file

newHandler cssSelector:
  # handles CSS selectors and properties
  add c.css, c.getSelectorGroup(node, scopetables)
  if node.pseudo.len > 0:
    for k, psNode in node.pseudo:
      add c.css, c.getSelectorGroup(psNode, scopetables)

newHandler fnDecl:
  # handles function declaration
  if likely(not c.inScope(node.fnIdent, scopetables)):
    c.stack(node.fnIdent, node, scopetables)
  else:
    compileErrorWithArgs(fnOverload, [node.fnName], node.meta)

proc getProperty(c: var Compiler, node: Node, k: string,
      len: int, scopetables: var seq[ScopeTable], ix: var int): string =
  # Returns `key`:`value pairs representing a CSS property and value
  if likely(c.minify):
    add result, k & ":"
  else:
    add result, spaces(2) & k & ":" & spaces(1)
  let high = node.pVal.high
  for p in 0..high:
    let v = c.getValue(node.pVal[p], scopetables)
    notnil v:
      add result, v.toString()
      case node.pVal[p].nt
      of ntSize:
        add result, $(node.pVal[p].sizeUnit)
      else: discard
      if p != high:
        add result, spaces(1) # todo check value separators
  if ix < len:
    add result, ";"
  add result, c.strNL # adds a `\n` when not minified
  inc ix

proc walkSubNodes(c: var Compiler, node, parent: Node,
      scopetables: var seq[ScopeTable], len: int, ix: var int) =
  # Handles nested statements
  case node.nt
  of ntProperty:
    if parent == nil:
      add c.deferredProps,
        c.getProperty(node, node.pName, len, scopetables, ix)
    else:
      parent.properties[node.pName] = node
  of cssSelectors:
    # Writes CSS selectors (classes, ids, tag names, pseudo classes)
    if parent == nil:
      add c.css, c.getSelectorGroup(node, scopetables)
    else:
      add c.deferred, c.getSelectorGroup(node, scopetables)
    if unlikely(node.pseudo.len > 0):
      for k, psNode in node.pseudo:
        add c.deferred, c.getSelectorGroup(psNode, scopetables, node)
  of ntCondStmt:
    c.innerCondDecl(node, scopetables, parent)
  of ntCommand:
    c.commandEval(node, scopetables, parent)
  else: discard

proc getSelectorGroup(c: var Compiler, node: Node,
      scopetables: var seq[ScopeTable], parent: Node = nil): string =
  ## Writes CSS properties inside a CSS selector block
  var ix = 1 # used to keep the CSS semi-colon under control
  newScope(scopetables)
  if node.innerNodes.len > 0:
    let len = node.innerNodes.len
    for innerKey, innerNode in node.innerNodes:
      c.walkSubNodes(innerNode, node, scopetables, len, ix)
  var skipped: bool
  let len = node.properties.len
  if len > 0:
    if node.parents.len > 0:
      let h = node.parents.high
      for p in 0..h:
        if node.nested:
          add result, node.parents[p] & node.ident
        else:
          add result, node.parents[p] & spaces(1) & node.ident
        if p != h:
          add result, ","
    else:
      if node.nt == ntPseudoSelector:
        assert parent != nil
        add result, parent.ident & ":"
      add result, node.ident
    if node.multipleSelectors.len > 0:
      add result, "," & node.multipleSelectors.join(",")
    if node.extendBy.len > 0:
      add result, "," & node.extendBy.join(", ")
    for concatVar in node.identConcat:
      var varMod = c.walkNodes(concatVar, scopetables)
      if likely(varMod != nil):
        add result, varMod.toString
      else: break
    add result, c.strCL # {
    for pName in node.properties.keys:
      add result, c.getProperty(node.properties[pName], pName, len, scopetables, ix)
    add result, c.strCR # }
    add result, c.deferred
    setLen c.deferred, 0
  clearScope(scopetables)

proc walkNodes(c: var Compiler, node: Node, scope: var seq[ScopeTable]): Node {.discardable.} =
  let
    callableHandler: FunctionHandler =
      case node.nt
      of cssSelectors: cssSelector
      of ntVariable:   varDecl
      of ntAssign:     varAssign
      of ntCondStmt:   condDecl
      of ntStmtList:   walkStmtList
      of ntCommand:    commandEval
      of ntImport:     importModule
      of ntFunction:   fnDecl
      of ntCallFunction: functionCall
      of ntForStmt:    loopEval
      # of ntCallFunction:  fnCallVoid
      of ntComment: nil
      else:
        # echo node.nt
        compileErrorWithArgs(invalidContext, [$(node.nt)])
  if likely(callableHandler != nil):
    discard callableHandler(c, node, scope)

#
# Public API
#
proc getCSS*(c: Compiler): string = c.css
proc hasErrors*(c: Compiler): bool = c.logger.errorLogs.len > 0

proc newCompiler*(p: Stylesheet, minify = false,
    imports: Stylesheets = Stylesheets()): Compiler =
  var c = Compiler(
    stylesheet: p,
    minify: minify,
    stylesheets: imports,
    globalScope: ScopeTable()
  )
  c.stylesheet.exports = c.globalScope
  when compileOption("app", "console"):
    c.logger = Logger(filePath: p.sourcePath)
  if not minify:
    c.strCL = spaces(1) & c.strCL & c.strNL
    c.strCR = c.strCR & c.strNL
  else:
    c.strNL = ""
  var scope = newSeq[ScopeTable]()
  for node in c.stylesheet.nodes:
    c.walkNodes(node, scope)
  result = c
  if unlikely(c.hasErrors):
    setLen(c.css, 0)

proc len*(c: Compiler): int =
  c.stylesheet.nodes.len

proc toCSS*(p: Stylesheet, minify = false): string =
  newCompiler(p, minify).getCSS