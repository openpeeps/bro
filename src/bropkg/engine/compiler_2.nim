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
  Compiler* = ref object
    css*, deferred, deferredProps: string
    program: Stylesheet
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
  
  CompileHandler = proc(c: Compiler, node: Node, scope: var seq[ScopeTable], parent: Node = nil)
  CallableFn = proc(c: Compiler, scope: var seq[ScopeTable], fnNode: Node, args: seq[Node]): Node {.nimcall.}

  BroAssert* = object of CatchableError
  CompilerError = object of CatchableError

# forward declaration
proc runHandler(c: Compiler, node: Node, scope: var seq[ScopeTable])

proc getSelectorGroup(c: Compiler, node: Node,
  scope: var seq[ScopeTable], parent: Node = nil): string

proc handleInnerNode(c: Compiler, node, parent: Node,
  scope: var seq[ScopeTable], len: int, ix: var int)

proc nodeEvaluator(c: Compiler, node: Node,
  scope: var seq[ScopeTable]): Node

proc infixEvaluator(c: Compiler, lht, rht: Node, op: InfixOp,
  scope: var seq[ScopeTable]): bool

proc fnCallVoid(c: Compiler, node: Node,
  scope: var seq[ScopeTable], parent: Node = nil)

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
      newEmptyNode(), # return type
      nnkIdentDefs.newTree(
        ident("c"),
        ident("Compiler"),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident("node"),
        ident("Node"),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident("scope"),
        nnkVarTy.newTree(nnkBracketExpr.newTree(ident("seq"), ident("ScopeTable"))),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident("parent"),
        ident("Node"),
        newNilLit()
      ),
    ],
    body
  )

#
# Local Scope Handlers
#
proc globalScope(c: Compiler, node: Node) =
  ## Add `node` to global scope
  case node.nt:
  of ntFunction, ntMixin:
    c.globalScope[node.fnIdent] = node
  of ntVariable:
    c.globalScope[node.varName] = node
  else: discard

proc toScope(scope: ScopeTable, node: Node) =
  ## Add `node` to current `scope`
  case node.nt:
  of ntFunction, ntMixin:
    scope[node.fnIdent] = node
  of ntVariable:
    scope[node.varName] = node
  else: discard

proc stack(c: Compiler, node: Node, scopetables: var seq[ScopeTable]) =
  ## Stack `node` into local/global scope
  if scopetables.len > 0:
    toScope(scopetables[^1], node)
  else:
    toScope(c.globalScope, node)

proc getScope(c: Compiler, name: string, scopetables: var seq[ScopeTable]): tuple[st: ScopeTable, index: int] =
  ## Search through available seq[ScopeTable] for `name`,
  if scopetables.len > 0:
    for i in countdown(scopetables.high, scopetables.low):
      if scopetables[i].hasKey(name):
        return (scopetables[i], i)
  if c.globalScope.hasKey(name):
    return (c.globalScope, 0)

proc getScope(c: Compiler, scopetables: var seq[ScopeTable]): ScopeTable =
  ## Returns the current scope
  if scopetables.len > 0:
    return scopetables[^1]
  return c.globalScope

proc inScope(c: Compiler, id: string, scopetables: var seq[ScopeTable]): bool =
  ## Perform a `getScope` call, if `nil` then returns false
  result = c.getScope(id, scopetables).st != nil

proc inScope(id: string, scopetables: var seq[ScopeTable]): bool =
  ## Performs a quick search in the current `ScopeTable`
  if scopetables.len > 0:
    return scopetables[^1].hasKey(id)

proc scoped(c: Compiler, id: string, scope: var seq[ScopeTable]): Node =
  ## Returns a callable node from `scope` table. Returns `nil` when not found
  let currentScope = c.getScope(id, scope)
  if currentScope.st != nil:
    result = currentScope.st[id]

proc getTypeInfo(node: Node): string =
  # Return type info for given Node
  case node.nt
  of ntCall:
    if node.callNode != nil:
      case node.callNode.nt:
      of ntAccessor:
        add result, getTypeInfo(node.callNode.accessorStorage)
      of ntVariable:
        case node.callNode.varMod.nt:
        of ntArray:
          # todo handle types of array (string, int, or mix for mixed values)
          add result, "$1[$2]($3)" % [$(node.callNode.varMod.nt),
                          "mix", $(node.callNode.varMod.arrayItems.len)]
        of ntObject:
          add result, "$1($2)" % [$(node.callNode.varMod.nt),
                          $(node.callNode.varMod.pairsVal.len)]
        else:
          add result, "$1[$2]" % [$ntVariable, $(node.callNode.varMod.nt)]
      else: discard
    else: discard
  of ntString:
    add result, "$1[$2]" % [$ntString, $node.sVal.len]
  of ntInt:
    add result, "$1" % [$ntInt]
  of ntFloat:
    add result, "$1" % [$ntFloat]
  of ntCallFunction:
    add result, "$1[$2]" % [$ntFunction, $node.callReturnType]
  of ntArray:
    add result, "$1[$2]($3)" % [$(node.nt), "mix", $(node.arrayItems.len)] # todo handle types of array (string, int, or mix for mixed values)
  of ntObject:
    add result, "$1($2)" % [$(node.nt), $(node.pairsVal.len)]
  of ntAccessor:
    add result, getTypeInfo(node.accessorStorage)
  of ntVariable:
    add result, getTypeInfo(node.varMod)
  else: discard

proc sizeString(v: Node): string =
  case v.sizeVal.nt
  of ntInt:   $(v.sizeVal.iVal) & $(v.sizeUnit)
  of ntFloat: $(v.sizeVal.fVal) & $(v.sizeUnit)
  else: "" # todo support for callables

proc dumpHook*(s: var string, v: seq[Node])
proc dumpHook*(s: var string, v: CritBitTree[Node])
# proc dumpHook*(s: var string, v: Color)

proc dumpHook*(s: var string, v: Node) =
  ## Dumps `v` node to stringified JSON using `pkg/jsony`
  case v.nt
  of ntString:s.add("\"" & $v.sVal & "\"")
  of ntFloat: s.add($v.fVal)
  of ntInt:   s.add($v.iVal)
  of ntBool:  s.add($v.bVal)
  of ntColor: s.add("\"" & $v.cVal  & "\"")
  of ntSize:  s.add("\"" & v.sizeString & "\"")
  of ntObject:
    s.dumpHook(v.pairsVal)
  of ntArray:
    s.dumpHook(v.arrayItems)
  of ntVariable:
    s.dumpHook(v.varMod)
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

proc toString(val: Node): string =
  ## Converts `val` node to string
  result =
    case val.nt
    of ntString:  val.sVal
    of ntFloat:   $(val.fVal)
    of ntInt:     $(val.iVal)
    of ntBool:    $(val.bVal)
    of ntColor:   toHtmlHex(val.cValue)
    of ntSize:    sizeString(val)
    of ntArray:   jsony.toJson(val.arrayItems)
    of ntObject:  fromJson(jsony.toJson(val.pairsVal)).pretty
    of ntStream:
      toString(val.streamContent)
    else: "null" # todo more things toString

#
# Compile Utils
#
template runCallable: untyped {.dirty.} =
  var scopedFn: Node = c.scoped(node.stackIdent, scope)
  if unlikely(scopedFn == nil):
    compileErrorWithArgs(fnUndeclared, [node.stackIdentName])
  var i = 0
  # evaluate given arguments
  # for callArg in node.stackArgs:
    # echo callArg
  if not scopedFn.fnFwdDecl:
    var fnScope = ScopeTable()
    for pName, pNode in scopedFn.fnParams:
      # populate function parameters
      fnScope[pName] = ast.newVariable(pName, c.nodeEvaluator(node.stackArgs[i], scope))
      fnScope[pName].varArg = true
      inc i
    add scope, fnScope
    let res = c.callableFn(scope, scopedFn, node.stackArgs)
    scope.delete(scope.high) # out of scope
    res
  else:
    i = 0
    var args: seq[Arg]
    for pName, pNode in scopedFn.fnParams:
      let val: Node = c.nodeEvaluator(node.stackArgs[i], scope)
      if likely(val != nil):
        if likely(val.nt == pNode[1]):
          add args, (pName, val)
        else: compileErrorWithArgs(fnMismatchParam, [pName, $val.nt, $pNode[1]])
      inc i
    call(std(scopedFn.fnSource)[0], scopedFn.fnName, args)

const callableFn: CallableFn =
  proc(c: Compiler, scope: var seq[ScopeTable], fnNode: Node, args: seq[Node]): Node {.nimcall.} =
    var ix = 1
    for innerNode in fnNode.fnBody.stmtList:
      case innerNode.nt
      of ntReturn:
        # echo innerNode.returnStmt
        # echo scope[^1].hasKey("$x")
        let returnNode = c.nodeEvaluator(innerNode.returnStmt, scope)
        if likely(returnNode != nil):
          return returnNode
        else: discard # error?
      else: c.handleInnerNode(innerNode, fnNode, scope, 0, ix)

#
# Math Evaluator
#
proc plus(lht, rht: int): int {.inline.} = lht + rht
proc plus(lht, rht: float): float {.inline.} = lht + rht

proc minus(lht, rht: int): int {.inline.} = lht - rht
proc minus(lht, rht: float): float {.inline.} = lht - rht

proc multi(lht, rht: int): int {.inline.} = lht * rht
proc multi(lht, rht: float): float {.inline.} = lht * rht

proc divide(lht, rht: int): float {.inline.} = lht / rht
proc divide(lht, rht: float): float {.inline.} = lht / rht
proc modulo(lht, rht: int): int {.inline.} = lht mod rht


template calc(calcHandle): untyped {.dirty.} =
  case lht.nt
  of ntInt:
    case rht.nt:
    of ntInt:
      let x = calcHandle(lht.iVal.toFloat, rht.iVal.toFloat)
      if x mod 1 != 0:
        Node(nt: ntFloat, fVal: x)
      else:
        Node(nt: ntInt, iVal: int(x))
    of ntFloat:
      Node(nt: ntFloat, fVal: calcHandle(toFloat(lht.iVal), rht.fVal))
    of ntCall, ntCallFunction:
      var rht = c.nodeEvaluator(rht, scope)
      c.mathEvaluator(lht, rht, infixOp, scope)
    of ntMathStmt:
      var rht = c.mathEvaluator(rht.mathLeft, rht.mathRight, rht.mathInfixOp, scope)
      c.mathEvaluator(lht, rht, infixOp, scope)
    else: nil
  of ntFloat:
    case rht.nt:
    of ntInt:
      let x = calcHandle(lht.fVal, rht.iVal.toFloat)
      if x mod 1 != 0:
        Node(nt: ntFloat, fVal: x)
      else:
        Node(nt: ntInt, iVal: int(x))
    of ntFloat:
      Node(nt: ntFloat, fVal: calcHandle(lht.fVal, rht.fVal))
    of ntCall, ntCallFunction:
      var rht = c.nodeEvaluator(rht, scope)
      c.mathEvaluator(lht, rht, infixOp, scope)
    of ntMathStmt:
      var rht = c.mathEvaluator(rht.mathLeft, rht.mathRight, rht.mathInfixOp, scope)
      c.mathEvaluator(lht, rht, infixOp, scope)
    # of ntCallFunction: ofMathCallStack
    else: nil
  of ntSize:
    case lht.sizeVal.nt
    of ntInt:
      case rht.nt
        of ntSize:
          if rht.sizeVal.nt == ntInt:
            newSize(calcHandle(lht.sizeVal.iVal, rht.sizeVal.iVal), lht.sizeUnit)
          elif rht.sizeVal.nt == ntFloat:
            newSize(calcHandle(toFloat(lht.sizeVal.iVal), rht.sizeVal.fVal), lht.sizeUnit)
          else: nil
        else: nil # todo handle int/float callables
    of ntFloat:
      case rht.nt
        of ntSize:
          if rht.sizeVal.nt == ntInt:
            newSize(calcHandle(lht.sizeVal.fVal, toFloat(rht.sizeVal.iVal)), lht.sizeUnit)
          elif rht.sizeVal.nt == ntFloat:
            newSize(calcHandle(lht.sizeVal.fVal, rht.sizeVal.fVal), lht.sizeUnit)
          else: nil
        else: nil # todo handle int/float callables
    else: nil
  of ntCall, ntCallFunction:
    var lht = c.nodeEvaluator(lht, scope)
    if lht.nt == ntMathStmt:
      lht = c.mathEvaluator(lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
    case rht.nt:
      of ntInt, ntFloat:
        c.mathEvaluator(lht, rht, infixOp, scope)
      of ntCall, ntCallFunction:
        var rht = c.nodeEvaluator(rht, scope)
        c.mathEvaluator(lht, rht, infixOp, scope)
      # of ntCallFunction: ofMathCallStack
      else: nil
  of ntMathStmt:
    var lht = c.mathEvaluator(lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
    var rht = rht
    case rht.nt
    of ntMathStmt:
      rht = c.mathEvaluator(rht.mathLeft, rht.mathRight, rht.mathInfixOp, scope)
    else: discard
    c.mathEvaluator(lht, rht, infixOp, scope)
  else: nil

proc mathEvaluator*(c: Compiler, lht, rht: Node, infixOp: MathOp, scope: var seq[ScopeTable]): Node =
  case infixOp
  of mPlus:   calc(plus)
  of mMinus:  calc(minus)
  of mMulti:  calc(multi)
  of mDiv:    calc(divide)
  # of mMod:    calcFloat(modulo)
  else: nil

#
# Infix Evaluator
#
template caseCallBody {.dirty.} =
  var rht = c.nodeEvaluator(rht, scope)
  if likely(rht != nil):
    return c.infixEvaluator(lht, rht, op, scope)
  return false

template printTypeMismatch {.dirty.} =
  compileErrorWithArgs(fnMismatchParam, [$op, $(rht.nt), $(lht.nt)], rht.meta)

template caseMathBody {.dirty.} =
  var rht = c.mathEvaluator(rht.mathLeft, rht.mathRight, rht.mathInfixOp, scope)
  if likely(rht != nil):
    return c.infixEvaluator(lht, rht, op, scope)
  return false

template caseCallStorageBody {.dirty.} =
  # not ideal, transforms ntArray/ntObject
  # to string then compares A <> B
  var rht = c.nodeEvaluator(rht, scope)
  return lht.toString == rht.toString

template caseSizeBody {.dirty.} =
  case rht.nt
  of ntSize:
    c.infixEvaluator(lht.sizeVal, rht.sizeVal, op, scope)
  of ntCall:
    var rht = c.nodeEvaluator(rht, scope)
    if likely(rht != nil):
      return c.infixEvaluator(lht, rht, op, scope)
    return false
  of ntMathStmt:
    caseMathBody
  else:
    return false

template caseLhtCallBody {.dirty.} =
  var lht = c.nodeEvaluator(lht, scope)
  if likely(lht != nil):
    return c.infixEvaluator(lht, rht, op, scope)
  return false

proc infixEvaluator(c: Compiler, lht, rht: Node, op: InfixOp, scope: var seq[ScopeTable]): bool =
  case op
  of EQ:
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:       lht.iVal == rht.iVal
      of ntFloat:     lht.iVal.toFloat == rht.fVal
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntFloat:
      case rht.nt:
      of ntFloat:     lht.fVal == rht.fVal
      of ntInt:       lht.fVal == rht.iVal.toFloat
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntCall:        caseLhtCallBody
    of ntBool:
      case rht.nt
      of ntBool:      lht.bVal == rht.bVal
      of ntCall:      caseCallBody
      else:           printTypeMismatch
    of ntColor:
      case rht.nt
      of ntColor:     lht.cValue == rht.cValue
      else: printTypeMismatch
    of ntString:
      case rht.nt
      of ntString:    lht.sVal == rht.sVal
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntArray:
      case rht.nt
      of ntArray:     lht.toString == rht.toString
      of ntCall:      caseCallStorageBody
      else:           printTypeMismatch
    of ntObject:
      case rht.nt
      of ntObject:    lht.toString == rht.toString
      of ntCall:      caseCallStorageBody
      else:           printTypeMismatch
    of ntSize:        caseSizeBody
    of ntCallFunction:
      var lht = c.nodeEvaluator(lht, scope)
      var rht = rht
      if rht.nt == ntCallFunction:
        rht = c.nodeEvaluator(rht, scope)
      return c.infixEvaluator(lht, rht, op, scope)
    of ntStream:
      case rht.nt
      of ntStream:    lht.toString == rht.toString
      else:           printTypeMismatch
    else:
      var lht = c.mathEvaluator(lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
      if likely(lht != nil):
        return c.infixEvaluator(lht, rht, op, scope)
      false
  of NE:
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:       lht.iVal != rht.iVal
      of ntFloat:     lht.iVal.toFloat != rht.fVal
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntFloat:
      case rht.nt:
      of ntFloat:     lht.fVal != rht.fVal
      of ntInt:       lht.fVal != rht.iVal.toFloat
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntCall:        caseLhtCallBody
    of ntBool:
      case rht.nt
      of ntBool:      lht.bVal != rht.bVal
      of ntCall:      caseCallBody
      else:           printTypeMismatch
    of ntColor:
      case rht.nt
      of ntColor:     lht.cValue != rht.cValue
      else: printTypeMismatch
    of ntString:
      case rht.nt
      of ntString:    lht.sVal != rht.sVal
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntArray:
      case rht.nt
      of ntArray:     lht.toString != rht.toString
      of ntCall:      caseCallStorageBody
      else:           printTypeMismatch
    of ntObject:
      case rht.nt
      of ntObject:    lht.toString != rht.toString
      of ntCall:      caseCallStorageBody
      else:           printTypeMismatch
    of ntSize:        caseSizeBody
    of ntCallFunction:
      var lht = c.nodeEvaluator(lht, scope)
      var rht = rht
      if rht.nt == ntCallFunction:
        rht = c.nodeEvaluator(rht, scope)
      return c.infixEvaluator(lht, rht, op, scope)
    of ntStream:
      case rht.nt
      of ntStream:    lht.toString != rht.toString
      else:           printTypeMismatch
    else:
      var lht = c.mathEvaluator(lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
      if likely(lht != nil):
        return c.infixEvaluator(lht, rht, op, scope)
      false
  of GT:
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:       lht.iVal > rht.iVal
      of ntFloat:     lht.iVal.toFloat > rht.fVal
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntFloat:
      case rht.nt:
      of ntFloat:     lht.fVal > rht.fVal
      of ntInt:       lht.fVal > rht.iVal.toFloat
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntCall:        caseLhtCallBody
    of ntSize:        caseSizeBody
    of ntCallFunction:
      var lht = c.nodeEvaluator(lht, scope)
      var rht = rht
      if rht.nt == ntCallFunction:
        rht = c.nodeEvaluator(rht, scope)
      return c.infixEvaluator(lht, rht, op, scope)
    else:
      var lht = c.mathEvaluator(lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
      if likely(lht != nil):
        return c.infixEvaluator(lht, rht, op, scope)
      false
  of GTE:
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:       lht.iVal >= rht.iVal
      of ntFloat:     lht.iVal.toFloat >= rht.fVal
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntFloat:
      case rht.nt:
      of ntFloat:     lht.fVal >= rht.fVal
      of ntInt:       lht.fVal >= rht.iVal.toFloat
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntCall:        caseLhtCallBody
    of ntSize:        caseSizeBody
    of ntCallFunction:
      var lht = c.nodeEvaluator(lht, scope)
      var rht = rht
      if rht.nt == ntCallFunction:
        rht = c.nodeEvaluator(rht, scope)
      return c.infixEvaluator(lht, rht, op, scope)
    else:
      var lht = c.mathEvaluator(lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
      if likely(lht != nil):
        return c.infixEvaluator(lht, rht, op, scope)
      false
  of LT:
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:       lht.iVal < rht.iVal
      of ntFloat:     lht.iVal.toFloat < rht.fVal
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntFloat:
      case rht.nt:
      of ntFloat:     lht.fVal < rht.fVal
      of ntInt:       lht.fVal < rht.iVal.toFloat
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntCall:        caseLhtCallBody
    of ntSize:        caseSizeBody
    of ntCallFunction:
      var lht = c.nodeEvaluator(lht, scope)
      var rht = rht
      if rht.nt == ntCallFunction:
        rht = c.nodeEvaluator(rht, scope)
      return c.infixEvaluator(lht, rht, op, scope)
    else:
      var lht = c.mathEvaluator(lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
      if likely(lht != nil):
        return c.infixEvaluator(lht, rht, op, scope)
      false
  of LTE:
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:       lht.iVal <= rht.iVal
      of ntFloat:     lht.iVal.toFloat <= rht.fVal
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntFloat:
      case rht.nt:
      of ntFloat:     lht.fVal <= rht.fVal
      of ntInt:       lht.fVal <= rht.iVal.toFloat
      of ntCall:      caseCallBody
      of ntMathStmt:  caseMathBody
      else:           printTypeMismatch
    of ntCall:        caseLhtCallBody
    of ntSize:        caseSizeBody
    of ntCallFunction:
      var lht = c.nodeEvaluator(lht, scope)
      var rht = rht
      if rht.nt == ntCallFunction:
        rht = c.nodeEvaluator(rht, scope)
      return c.infixEvaluator(lht, rht, op, scope)
    else:
      var lht = c.mathEvaluator(lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
      if likely(lht != nil):
        return c.infixEvaluator(lht, rht, op, scope)
      false
  else:
    false

proc walkObject*(c: Compiler, tree: CritBitTree, index: Node, scope: var seq[ScopeTable]): Node =
  case index.nt
  of ntString:
    result = tree[index.sVal]
  of ntCall:
    result = tree[c.nodeEvaluator(index, scope).sVal]
  else: discard

proc walkAccessorStorage(c: Compiler, node, index: Node, scope: var seq[ScopeTable]): Node =
  case node.nt:
  of ntAccessor:
    var x: Node
    if node.accessorType == ntArray:
      # handle an `ntArray` storage
      x = c.walkAccessorStorage(node.accessorStorage, node.accessorKey, scope)
      return c.walkAccessorStorage(x, index, scope)
    # otherwise handle `ntObject` storage
    x = c.walkAccessorStorage(node.accessorStorage, node.accessorKey, scope)
    return c.walkAccessorStorage(x, index, scope)
  of ntObject:
    try:
      if index.nt == ntCall:
        return c.walkObject(node.pairsVal, index, scope)
      result = node.pairsVal[index.sVal]
    except FieldDefect:
      compileErrorWithArgs(invalidAccessorStorage, [index.toString])
  of ntArray:
    try:
      if index.nt == ntCall:
        return node.arrayItems[c.nodeEvaluator(index, scope).iVal]
      result = node.arrayItems[index.iVal]
    except FieldDefect:
      compileErrorWithArgs(invalidAccessorStorage, [index.toString])
  of ntVariable:
    var varNode = c.scoped(node.varName, scope)
    return c.walkAccessorStorage(varNode.varMod, index, scope)
  of ntStream:
    case node.streamContent.kind:
    of JObject:
      if index.nt == ntCall:
        return toNode(node.streamContent[c.nodeEvaluator(index, scope).sVal])
      result = toNode(node.streamContent[index.sVal])
    of JArray:
      if index.nt == ntCall:
        return toNode(node.streamContent[c.nodeEvaluator(index, scope).iVal])
      result = toNode(node.streamContent[index.iVal])
    else:
      result = toNode(node.streamContent)
  else: discard

proc nodeEvaluator(c: Compiler, node: Node, scope: var seq[ScopeTable]): Node =
  ## Evaluates `node`
  case node.nt
  of ntInt, ntFloat, ntBool, ntString, ntColor, ntSize:
    result = node
  of ntCall:
    var varNode = c.scoped(node.callIdent, scope)
    if likely(varNode != nil):
      if node.callNode != nil:
        case node.callNode.nt
        of ntAccessor:
          # node.callNode.accessorStorage = varNode.varValue
          var x = c.walkAccessorStorage(node.callNode.accessorStorage, node.callNode.accessorKey, scope)
          if likely(x != nil):
            return x
          echo $invalidAccessorStorage
          # compileErrorWithArgs(invalidAccessorStorage)
        else: return varNode.varMod
      else:
        if varNode.varMod != nil:
          return varNode.varMod
        return varNode.varValue
    compileErrorWithArgs(undeclaredVariable, [node.callIdent], node.meta)
  of ntInfix:
    return ast.newBool(c.infixEvaluator(node.infixLeft, node.infixRight, node.infixOp, scope))
  of ntAccQuoted:
    var accValues: seq[(string, string)]
    for accVar in node.accVars:
      var accVal: (string, string)
      accVal[0] = "$bro"
      case accVar.nt
      of ntCall:
        add accVal[0], $(hash(accVar.callIdent[1..^1])) # variable name without `$`
      of ntInt:
        add accVal[0], $(hash($accVar.iVal))
      of ntMathStmt, ntInfix:
        add accVal[0], $(hash(accVar)) 
      else: discard
      var accVarNode = c.nodeEvaluator(accVar, scope)
      if likely(accVarNode != nil):
        accVal[1] = toString(c.nodeEvaluator(accVar, scope))
        add accValues, accVal
      else: return
    return ast.newString(node.accVal.multiReplace(accValues))
  of ntMathStmt:
    # echo node
    result = c.mathEvaluator(node.mathLeft, node.mathRight, node.mathInfixOp, scope)
    if likely(result != nil):
      return # result
    # error?
  of ntObject:
    for k, v in node.pairsVal.mpairs:
      v = c.nodeEvaluator(v, scope)
    result = node
  of ntArray:
    for v in node.arrayItems.mitems:
      v = c.nodeEvaluator(v, scope)
    result = node
  of ntCallFunction:
    return runCallable()
  # of ntForStmt:
    # echo node
  # of ntDotExpr:
  #   var lht: Node
  #   case node.dotLeft.nt:
  #     of ntCall:
  #       lht = c.nodeEvaluator(node.dotLeft)
  #     else: discard
  #   if lht != nil:
  #     case 
  #     return c.nodeEvaluator(node.dotRight)
  else:
    echo node
    echo node.nt
    result = nil

include handlers/[wImport, wAssignment, wFunction, wCommand, wCond, wFor]

newHandler cssSelector:
  ## Handles CSS selectors and properties
  add c.css, c.getSelectorGroup(node, scope)
  if node.pseudo.len > 0:
    for k, psNode in node.pseudo:
      add c.css, c.getSelectorGroup(psNode, scope)

#
# CSS Selectors, Properties and other nested nodes
#
proc getValue(c: Compiler, vals: seq[Node], scope: var seq[ScopeTable]): string =
  var strVal: seq[string]
  for v in vals:
    var value = c.nodeEvaluator(v, scope)
    if likely(value != nil):
      add strVal, value.toString
  result = strVal.join(" ") # todo make it work with a valid separator (space, colon) 

proc getProperty(c: Compiler, node: Node, k: string,
      len: int, scope: var seq[ScopeTable], ix: var int): string =
  # Returns `key`:`value pairs representing a CSS property and value
  if likely(c.minify):
    add result, k & ":"
  else:
    add result, spaces(2) & k & ":" & spaces(1)
  add result,  c.getValue(node.pVal, scope)
  if ix < len:
    add result, ";"
  add result, c.strNL # adds a `\n` when not minified
  inc ix

proc handleInnerNode(c: Compiler, node, parent: Node,
      scope: var seq[ScopeTable], len: int, ix: var int) =
  # Handles nested statements
  case node.nt
  of ntProperty:
    # Writes CSS properties
    if parent == nil:
      add c.deferredProps,
        c.getProperty(node, node.pName, len, scope, ix)
    else:
      parent.properties[node.pName] = node
  of cssSelectors:
    # Writes CSS selectors (classes, ids, tag names, pseudo classes)
    if parent == nil:
      add c.css, c.getSelectorGroup(node, scope)
    else:
      add c.deferred, c.getSelectorGroup(node, scope)
    if unlikely(node.pseudo.len > 0):
      for k, psNode in node.pseudo:
        add c.deferred, c.getSelectorGroup(psNode, scope, node)
  of ntVariable:      c.handleVarDef(node, scope, parent)
  of ntAssign:        c.handleAssignment(node, scope, parent)
  of ntCallFunction:  c.fnCallVoid(node, scope)
  of ntFunction:   c.handleFunctionDef(node, scope)
  of ntCommand:    c.handleCommand(node, scope)
  of ntCondStmt:   c.handleCondition(node, scope)
  else: discard

proc getSelectorGroup(c: Compiler, node: Node,
      scope: var seq[ScopeTable], parent: Node = nil): string =
  ## Writes CSS properties inside a CSS selector block
  var ix = 1 # used to keep the CSS semi-colon under control
  var localScope = ScopeTable()
  scope.add(localScope)
  if node.innerNodes.len > 0:
    let len = node.innerNodes.len
    for innerKey, innerNode in node.innerNodes:
      c.handleInnerNode(innerNode, node, scope, len, ix)
  var skipped: bool
  let len = node.properties.len
  if len > 0:
    if node.parents.len > 0:  
      add result, node.parents.join(" ") & spaces(1) & node.ident
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
      var varMod = c.nodeEvaluator(concatVar, scope)
      if likely(varMod != nil):
        add result, varMod.toString
      else: break
    add result, c.strCL # {
    for pName in node.properties.keys:
      add result, c.getProperty(node.properties[pName], pName, len, scope, ix)
    add result, c.strCR # }
    add result, c.deferred
    setLen c.deferred, 0
  scope.delete(scope.high) # out of scope

proc runHandler(c: Compiler, node: Node, scope: var seq[ScopeTable]) =
  let
    compileHandler: CompileHandler =
      case node.nt
      of cssSelectors: cssSelector
      of ntVariable:   handleVarDef
      of ntAssign:     handleAssignment
      of ntCallFunction:  fnCallVoid
      of ntFunction:   handleFunctionDef
      of ntCommand:    handleCommand
      of ntCondStmt:   handleCondition
      of ntImport:     importModule
      of ntComment: nil
      of ntForStmt:    forBlock
      else:
        echo node.nt
        nil
  if likely(compileHandler != nil):
    compileHandler(c, node, scope)


#
# Public API
#

proc getCSS*(c: Compiler): string =
  result = c.css

proc hasErrors*(c: Compiler): bool =
  c.logger.errorLogs.len > 0

proc newCompiler*(p: Stylesheet, minify = false,
    imports: Stylesheets = Stylesheets()): Compiler =
  var c = Compiler(program: p, minify: minify,
            stylesheets: imports, globalScope: ScopeTable())
  # p.stylesheets["std/system"] = 
  when compileOption("app", "console"):
    c.logger = Logger(filePath: p.sourcePath)
  if not minify:
    c.strCL = spaces(1) & c.strCL & c.strNL
    c.strCR = c.strCR & c.strNL
  else:
    c.strNL = ""
  var scope = newSeq[ScopeTable]()
  for i in 0..c.program.nodes.high:
    c.runHandler(c.program.nodes[i], scope)
  result = c
  if unlikely(c.hasErrors):
    setLen(c.css, 0)

proc len*(c: Compiler): int =
  c.program.nodes.len

proc toCSS*(p: Stylesheet, minify = false): string =
  newCompiler(p, minify).getCSS