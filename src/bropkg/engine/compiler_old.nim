# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import pkg/[jsony, stashtable]
import std/[tables, strutils, macros, sequtils, json,
          algorithm, math, oids, hashes, terminal, threadpool, enumutils]
import ./ast, ./sourcemap, ./stdlib, ./logging

type
  Warning* = tuple[msg: string, line, col: int]
  Compiler* = ref object
    css*, deferred, deferredProps: string
    program: Stylesheet
    sourceMap: SourceInfo
    minify: bool
    warnings*: seq[Warning]
    strCL: string = "{"
    strCR: string = "}"
    strNL: string = "\n"
    stylesheets: Stylesheets
    localScope: seq[ScopeTable]
    globalScope: ScopeTable
    when compileOption("app", "console"):
      logger*: Logger
  
  CompileHandler = proc(c: Compiler, node: Node, scope: var seq[ScopeTable], parent: Node = nil)

  BroAssert* = object of CatchableError
  CompilerError = object of CatchableError

type
    CallableFn = proc(c: Compiler, scope: var seq[ScopeTable], fnNode: Node, args: seq[Node]): Node {.nimcall.}

# forward declaration
proc interpret(c: Compiler, node: Node, scope: var seq[ScopeTable])
proc getSelectorGroup(c: Compiler, node: Node, scope: ScopeTable = nil, parent: Node = nil): string
# proc handleInnerNode(c: Compiler, node, parent: Node, scope: ScopeTable = nil, len: int, ix: var int)
# proc handleCallStack(c: Compiler, node: Node, scope: ScopeTable, parent: Node = nil): Node
proc getValue(c: Compiler, v: Node, scope: ScopeTable): Node

macro newHandler(name: static string, body: untyped) =
  newProc(ident(name),
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

# eval
include ./eval

proc getTypeInfo(node: Node): string =
  # Return type info for given Node
  case node.nt
  of ntCall:
    if node.callNode != nil:
      case node.callNode.nt:
      of ntAccessor:
        add result, getTypeInfo(node.callNode.accessorStorage)
      of ntVariable:
        case node.callNode.varValue.nt:
        of ntArray:
          # todo handle types of array (string, int, or mix for mixed values)
          add result, "$1[$2]($3)" % [$(node.callNode.varValue.nt),
                          "mix", $(node.callNode.varValue.arrayItems.len)]
        of ntObject:
          add result, "$1($2)" % [$(node.callNode.varValue.nt),
                          $(node.callNode.varValue.pairsVal.len)]
        else:
          add result, "$1[$2]" % [$ntVariable, $(node.callNode.varValue.nt)]
      else: discard
    else: discard
  of ntString:
    add result, "$1($2)" % [$ntString, $node.sVal.len]
  of ntInt:
    add result, "$1" % [$ntInt]
  of ntFloat:
    add result, "$1" % [$ntFloat]
  of ntCallStack:
    add result, "$1[$2]" % [$ntFunction, $node.stackReturnType]
  of ntArray:
    add result, "$1[$2]($3)" % [$(node.nt), "mix", $(node.arrayItems.len)] # todo handle types of array (string, int, or mix for mixed values)
  of ntObject:
    add result, "$1($2)" % [$(node.nt), $(node.pairsVal.len)]
  of ntAccessor:
    add result, getTypeInfo(node.accessorStorage)
  of ntVariable:
    add result, getTypeInfo(node.varValue)
  else: discard

proc getCSS*(c: Compiler): string =
  result = c.css

proc hasErrors*(c: Compiler): bool = c.logger.errorLogs.len > 0

proc prefix(node: Node): string =
  # Prefix CSS selector, `.myclass` for ntClassSelector,
  # `#myId` for `ntIDSelector` and so on
  result =
    case node.nt
    of ntClassSelector: "." & node.ident
    of ntIDSelector: "#" & node.ident
    else: node.ident

proc getOtherParents(node: Node, childSelector: string): string =
  # Retrieve all CSS sibling selectors
  var res: seq[string]
  for parent in node.parents:
    if likely(node.nested == false):
      if unlikely(node.nt == ntPseudoSelector):
        add res, parent & ":" & childSelector
      else:
        add res, parent & " " & childSelector
    else:
      add res, parent & childSelector
  result = res.join(",")

#
# Serialization API
#
proc dumpHook*(s: var string, v: Node) =
  case v.nt
  of ntString:
    s.add("\"" & $v.sVal & "\"")
  of ntFloat:
    s.add($v.fVal)
  of ntInt:
    s.add($v.iVal)
  of ntBool:
    s.add($v.bVal)
  of ntColor:
    s.add($v.cVal)
  of ntVariable:
    s.dumpHook(v.varValue)
  else: discard

template handleVariableValue(varNode: Node, scope: ScopeTable) {.dirty.} =
  if varNode.varValue != nil:
    return c.getValue(varNode.varValue, nil)
  result = c.getValue(scope[varNode.varName].varValue, nil)

proc sizeToString(v: Node): string =
  case v.sizeVal.nt
  of ntInt:   $(v.sizeVal.iVal) & $(v.sizeUnit)
  of ntFloat: $(v.sizeVal.fVal) & $(v.sizeUnit)
  else: "" # todo support for callables

proc toString(c: Compiler, v: Node, scope: ScopeTable = nil): string =
  # Return stringified version of `v`
    result =
      case v.nt
      of ntString: v.sVal
      of ntFloat:  $(v.fVal)
      of ntInt:    $(v.iVal)
      of ntSize:   sizeToString(v)
      of ntBool:   $(v.bVal)
      of ntColor:  $(v.cVal)
      of ntArray:     jsony.toJson(v.arrayItems)
      of ntObject:    jsony.toJson(v.pairsVal)
      of ntAccQuoted:
        var accValues: seq[(string, string)]
        for accVar in v.accVars:
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
          accVal[1] = c.toString(c.getValue(accVar, scope))
          add accValues, accVal
        v.accVal.multiReplace(accValues)
      of ntStream:
        toString(v.streamContent)
      of ntMathStmt:
        let total = c.evalMathInfix(v.mathLeft, v.mathRight, v.mathInfixOp, scope)
        if total.nt == ntInt:
          $(v.iVal)
        else: # a float number
          $(v.fVal)
      else: ""

proc getValue(c: Compiler, v: Node, scope: ScopeTable): Node =
  case v.nt
  of ntCall:
    if v.callNode != nil:
      case v.callNode.nt
        of ntAccessor:
          var x: Node
          if v.callNode.accessorType == ntArray:
            # handle `ntArray` storages
            x = walkAccessorStorage(v.callNode.accessorStorage,
                  v.callNode.accessorKey, scope)
            return c.getValue(x, scope)  
          try:
            # handle `ntObject` storages
            x = walkAccessorStorage(v.callNode.accessorStorage,
                  v.callNode.accessorKey, scope)
            result = c.getValue(x, scope)
          except KeyError as e:
            newError(c.logger, internalError, 0, 0, true, e.msg)
        of ntVariable:
          handleVariableValue(v.callNode, scope)
        of ntReturn:
          result = c.handleCallStack(v.callNode, scope, nil)
        else: discard
    else:
      return c.getValue(scope[v.callIdent], nil)
  of ntAssign:
    echo v
    result = v
  of ntCallStack:
    result = c.handleCallStack(v, scope, nil)
  of ntVariable:
    handleVariableValue(v, scope)
  of ntInfix:
    result = newBool(c.evalInfix(v.infixLeft, v.infixRight, v.infixOp, scope))
  of ntMathStmt:
    result = c.evalMathInfix(v.mathLeft, v.mathRight, v.mathInfixOp, scope)
  else:
    result = v

proc getValue(c: Compiler, vals: seq[Node], scope: ScopeTable): string =
  var strVal: seq[string]
  for v in vals:
    add strVal, c.toString(c.getValue(v, scope))
  result = strVal.join(" ") # todo make it work with a valid separator (space, colon) 

const callableFn: CallableFn =
  proc(c: Compiler, scope: var seq[ScopeTable], fnNode: Node, args: seq[Node]): Node {.nimcall.} =
    var ix = 1
    for innerNode in fnNode.fnBody.stmtList:
      case innerNode.nt
      of ntReturn:
        return c.getValue(innerNode.returnStmt, scope[^1])
      else: discard
      # else: c.handleInnerNode(innerNode, fnNode, scope[^1], 0, ix)

proc getProperty(c: Compiler, n: Node, k: string, 
  len: int, scope: ScopeTable, ix: var int): string =
  # Get pairs of `key`:`value`;
  var
    ii = 1
    # vLen = n.pVal.len
  if likely(c.minify):
    add result, k & ":"
  else:
    add result, spaces(2) & k & ":" & spaces(1)
  add result, c.getValue(n.pVal, scope)
  if ix < len:
    add result, ";"
  add result, c.strNL # add \n if not minified
  inc ix

# Writers
# include ./handlers/[wCond, wFor]

proc getSelectorGroup(c: Compiler, node: Node,
      scope: ScopeTable = nil, parent: Node = nil): string =
  # Write CSS selectors and properties
  var ix = 1
  # if likely(node.innerNodes.len > 0):
    # for innerKey, innerNode in node.innerNodes:
      # c.handleInnerNode(innerNode, node, scope, node.innerNodes.len, ix)
  var
    skipped: bool
    len = node.properties.len
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
      # write other selectors that extends from current selector
      add result, "," & node.extendBy.join(", ")
    for idConcat in node.identConcat:
      case idConcat.nt
      of ntCall:
        var scopeVar: Node
        if idConcat.callNode.varValue != nil:
          add result, c.toString(c.getValue(idConcat, nil))
        else:
          scopeVar = scope[idConcat.callNode.varName]
          var varValue = scopeVar.varValue
          case varValue.nt
          of ntColor:
            # todo handle colors at parser level
            idConcat.callNode.varValue = varValue
            add result, c.toString(c.getValue(idConcat, nil))
          else:
            idConcat.callNode.varValue = varValue
            add result, c.toString(c.getValue(idConcat, nil))
      of ntMathStmt:
        add result, c.toString(c.getValue(idConcat, nil))
      of ntString, ntInt, ntFloat, ntBool:
        add result, c.toString(c.getValue(idConcat, nil))
      else: discard
    add result, c.strCL # {
    for pName in node.properties.keys:
      add result, c.getProperty(node.properties[pName], pName, len, scope, ix)
    add result, c.strCR # }
    add result, c.deferred
    setLen c.deferred, 0
    # add c.css, c.deferred
    # setLen(c.deferred, 0)


# proc handleCommand(c: Compiler, node: Node, scope: ScopeTable = nil) =
#   case node.cmdIdent
#   of cmdEcho:
#     let meta = " (" & $(node.cmdMeta.line) & ":" & $(node.cmdMeta.pos) & ") "
#     case node.cmdValue.nt:
#     of ntInfix:
#       let output = c.evalInfix(node.cmdValue.infixLeft,
#         node.cmdValue.infixRight, node.cmdValue.infixOp, scope)
#       stdout.styledWriteLine(fgGreen, "Debug", fgDefault,
#             meta, fgDefault, getTypeInfo(node.cmdValue) & "\n" & $(output))
#     of ntMathStmt:
#       let
#         mNode = node.cmdValue
#         total =
#           c.evalMathInfix(mNode.mathLeft, mNode.mathRight, mNode.mathInfixOp, scope)
#         output =
#           case total.nt
#           of ntInt:   $(total.iVal)
#           of ntFloat: $(total.fVal)
#           of ntSize:  sizeToString(total)
#           else: ""
#       stdout.styledWriteLine(fgGreen, "Debug", fgDefault, meta, fgDefault, mNode.getTypeInfo & "\n" & $(output))    
#     # of ntInfo:
#       # stdout.styledWriteLine(fgGreen, "Debug", fgDefault, meta, fgMagenta,
#                             # "[[" & $(node.cmdValue.nodeType) & "]]")
#     else:
#       let varValue = c.getValue(node.cmdValue, scope)
#       if likely(varValue != nil):
#         var output: string
#         case varValue.nt:
#         of ntMathStmt:
#           output =
#             if varValue.mathResult.nt == ntInt:
#               $(varValue.mathResult.iVal)
#             else:
#               $(varValue.mathResult.fVal)
#         else:
#           output = c.toString(varValue)
#         stdout.styledWriteLine(fgGreen, "Debug", fgDefault, meta, fgMagenta,
#                           getTypeInfo(node.cmdValue) & "\n", fgDefault, output)
#   of cmdAssert:
#     case node.cmdValue.nt:
#     of ntInfix:
#       let output = c.evalInfix(node.cmdValue.infixLeft, node.cmdValue.infixRight, node.cmdValue.infixOp, scope)
#       if not output:
#         raise newException(BroAssert, "($1:$2) Assertion failed" % [$(node.cmdMeta.line), $(node.cmdMeta.pos)])
#     else: discard

# proc handleCallStack(c: Compiler, node: Node, scope: ScopeTable, parent: Node = nil): Node =
#   var
#     callable: Node
#     stmtScope: ScopeTable
#   if scope != nil:
#     if scope.hasKey(node.stackIdent):
#       callable = scope[node.stackIdent]
#   if callable == nil:
#     callable = c.program.getStack()[node.stackIdent]
#   if not callable.fnFwdDecl: # todo at parser level
#     var ix = 0
#     stmtScope = callable.fnBody.stmtScope
#     case callable.nt
#     of ntFunction:
#       for pName in callable.fnParams.keys():
#         stmtScope[pName].varValue = node.stackArgs[ix]
#         inc ix
#       ix = 1
#       for n in callable.fnBody.stmtList:
#         case n.nt
#         of ntReturn:
#           return c.getValue(n.returnStmt, stmtScope)
#         else: c.handleInnerNode(n, callable, stmtScope, 0, ix)
#     of ntMixin:
#       for pName in callable.fnParams.keys():
#         stmtScope[pName].varValue = node.stackArgs[ix]
#         inc ix
#       ix = 1
#       for n in callable.fnBody.stmtList:
#         c.handleInnerNode(n, parent, stmtScope, 0, ix)
#     else: discard
#   else:
#     echo node.stackArgs
#     # echo c.getValue(node.stackArgs[0], scope)
#     # let nimCallTypes = strings().get(callable.fnName, strEndsWithFn)
#     # echo nimCallTypes
#     # for i in 0..nimCallTypes.high:
#     #   node.stackArgs 
#     let x = strings().call(callable.fnName, strEndsWithFn).get()
#     # x((c.toString(c.getValue(node.stackArgs[0], scope), scope), c.toString(c.getValue(node.stackArgs[1], scope), scope)))
#     return newBool(x(node.stackArgs[0], node.stackArgs[1]))

# proc handleInnerNode(c: Compiler, node, parent: Node,
#       scope: ScopeTable = nil, len: int, ix: var int) =
#   case node.nt:
#   of ntProperty:
#     if parent == nil:
#       add c.deferredProps,
#         c.getProperty(node, node.pName, len, scope, ix)
#     else:
#       parent.properties[node.pName] = node
#   of ntClassSelector, ntTagSelector,
#     ntIDSelector, ntRoot, ntUniversalSelector:
#     if parent == nil:
#       add c.css, c.getSelectorGroup(node, scope)
#     else:
#       add c.deferred, c.getSelectorGroup(node, scope)
#     if unlikely(node.pseudo.len > 0):
#       for k, pseudoNode in node.pseudo:
#         add c.deferred, c.getSelectorGroup(pseudoNode, scope, node)
#   of ntForStmt:
#     c.handleForStmt(node, parent, scope)
#   of ntCondStmt:
#     c.handleCondStmt(node, parent, scope)
#   of ntCaseStmt:
#     c.handleCaseStmt(node, parent, scope)
#   of ntExtend:
#     for eKey, eProp in node.extendProps:
#       add c.css, c.getProperty(eProp, eKey,
#                     node.extendProps.len, scope, ix)
#   of ntImport:
#     c.handleImportStmt(node, scope)
#   of ntCommand:
#     c.handleCommand(node, scope)
#   of ntCallStack:
#     discard c.handleCallStack(node, scope, parent)
#   of ntVariable:
#     case node.varValue.nt:
#     of ntMathStmt:
#       node.varValue.mathResult = c.evalMathInfix(node.varValue.mathLeft, node.varValue.mathRight, node.varValue.mathInfixOp, scope)
#     else: discard
#   else: discard

#
# Logical / Math Evaluators
#
proc getInfixValue(c: Compiler, infix: Node, scope: var seq[ScopeTable]): bool {.inline.} =
  c.evalInfix(infix.infixLeft, infix.infixRight, infix.infixOp, scope[0])

proc getMathValue(c: Compiler, infix: Node, scope: var seq[ScopeTable]): Node {.inline.} =
  c.evalMathInfix(infix.mathleft, infix.mathRight, infix.mathInfixOp, c.getScope(scope))


proc modifier(c: Compiler, node: Node, scope: var seq[ScopeTable]): Node =
  ## Evaluates and modify `node`
  case node.nt
  of ntInt, ntFloat, ntBool, ntString: node
  of ntMathStmt:
    # echo node
    # node
    if node.mathleft.nt == ntCall:
      node.mathLeft = c.getValue(node.mathLeft, c.getScope(scope))
      # echo c.getValue(c.getScope(node.mathLeft.callIdent, scope), c.getScope(scope))
    node
  else:
    echo node.nt
    nil

# proc getScopeVar(c: Compiler, id: string, scope: var seq[ScopeTable]): Node =
#   let currScope = c.getScope(id, scope)
#   if currScope.st != nil:


newHandler "varAssignment":
  ## Handles variable assignments
  let currScope = c.getScope(node.asgnVarIdent, scope)
  if currScope.st != nil:
    echo node
    let scopeVar = currScope.st[node.asgnVarIdent]
    let varType = scopeVar.varValue.getNodeType
    let varTypeAsgn = node.asgnVal.getNodeType
    echo c.modifier(node.asgnVal, scope)
    if likely(varType == varTypeAsgn):
      # echo c.getValue(node.asgnVal, c.getScope(scope))
      currScope.st[node.asgnVarIdent].varValue = node.asgnVal
      return
    compileErrorWithArgs(fnMismatchParam, [scopeVar.varName, $varTypeAsgn, $varType], scopeVar.meta)
  compileErrorWithArgs(undeclaredVariable, [node.asgnVarIdent], node.meta)

newHandler "varDefinition":
  ## Handles Variable Definitions
  if likely(c.inScope(node.varName, scope) == false):
    case node.varValue.nt
    of ntCall:
      var valNode = c.getValue(node.varValue, c.getScope(scope))
      if likely(valNode != nil):
        node.varValue = valNode
    else: discard
    c.stack(node, scope)
  else:
    compileErrorWithArgs(varRedefine, [node.varName], node.meta)

newHandler "command":
  case node.cmdIdent
  of cmdEcho:
    let meta = " (" & $(node.cmdMeta.line) & ":" & $(node.cmdMeta.pos) & ") "
    case node.cmdValue.nt:
    of ntInfix:
      stdout.styledWriteLine(fgGreen, "Debug", fgDefault,
        meta, fgDefault, node.cmdValue.getTypeInfo & "\n" &
          $(c.getInfixValue(node.cmdValue, scope)))
    of ntMathStmt:
      let
        total = c.getMathValue(node.cmdValue, scope)
        output =
          case total.nt
          of ntInt:   $(total.iVal)
          of ntFloat: $(total.fVal)
          of ntSize:  sizeToString(total)
          else: ""
      stdout.styledWriteLine(fgGreen, "Debug", fgDefault,
        meta, fgDefault, node.cmdValue.getTypeInfo & "\n" & $(output))    
    else:
      let varValue = c.getValue(node.cmdValue, c.getScope(scope))
      if likely(varValue != nil):
        var output: string
        case varValue.nt:
        of ntMathStmt:
          output =
            if varValue.mathResult.nt == ntInt:
              $(varValue.mathResult.iVal)
            else:
              $(varValue.mathResult.fVal)
        else:
          output = c.toString(varValue)
        stdout.styledWriteLine(fgGreen, "Debug", fgDefault, meta, fgMagenta,
                getTypeInfo(varValue) & "\n", fgDefault, output)
  of cmdAssert:
    if c.getInfixValue(node.cmdValue, scope) == false:
      raise newException(BroAssert, "($1:$2) Assertion failed" %
          [$(node.cmdMeta.line), $(node.cmdMeta.pos)])

newHandler "writeSelector":
  ## Handles CSS selectors, properties
  ## and any other inner nodes
  add c.css, c.getSelectorGroup(node, c.globalScope)
  if unlikely(node.pseudo.len > 0):
    for k, pseudoNode in node.pseudo:
      add c.css, c.getSelectorGroup(pseudoNode, c.globalScope, node)

newHandler "fnDefinition":
  ## Defines a function and  
  # fnCall()
  # discard x(node)
  # c.globalScope[node]
  if likely(c.inScope(node.fnIdent, scope) == false):
    c.stack(node, scope)
  else: compileErrorWithArgs(fnOverload, [node.fnIdent])

  # echo $cast[int](x.addr)
  # var xptr = cast[pointer](x)
  # let fn = cast[Fn](xptr)
  # discard c.toString x(newString("Hello"))
  # discard c.toString fn(newString("Hello Again!"))

newHandler "fnCallVoid":
  ## Handle call functions with no return type 
  var fnNode: Node
  let currScope = c.getScope(node.stackIdent, scope)
  if currScope.st != nil:
    fnNode = currScope.st[node.stackIdent]
    if likely(fnNode != nil):
      # echo hash(node.stackIdent)
      if fnNode.fnFwdDecl:
        let x = strings().call(fnNode.fnName, strEndsWithFn).get()
        echo newBool(x(node.stackArgs[0], node.stackArgs[1]))
      else:
        var i = 0
        var fnScope = ScopeTable()
        for pIdent, pDef in fnNode.fnparams:
          fnScope[pIdent] = ast.newVariable(pIdent, node.stackArgs[i])
          fnScope[pIdent].varArg = true
          inc i
          # fnScope[pIdent] = ast.newVariable(pIdent, ast.newString("Hello!"))
          # fnScope[pIdent].varArg = true
        add scope, fnScope
        discard c.callableFn(scope, fnNode, node.stackArgs)
        # use fnNode
        scope.delete(scope.high)
  else:
    if c.globalScope.hasKey(node.stackIdent):
      fnNode = c.globalScope[node.stackIdent]
      if likely(fnNode != nil):
        discard c.callableFn(scope, fnNode, node.stackArgs)
    else: compileErrorWithArgs(fnUndeclared, [node.stackIdentName])

newHandler "importModule":
  ## Handle CSS/BASS imports
  if likely(c.stylesheets != nil):
    for fpath in node.modules:
      c.stylesheets.withValue(fpath):
        c.logger.filePath = value[].sourcePath
        for node in value[].nodes:
          c.interpret(node, scope)
    c.logger.filePath = c.program.sourcePath # back to main file

newHandler "ifCondition":
  ## Handle blocks of `if`, `elif` `else` conditional statements
  var
    ix = 1
    tryElse: bool
    lht: Node = node.ifInfix.infixleft
    rht: Node = node.ifInfix.infixRight
  if c.evalInfix(lht, rht, node.ifInfix.infixOp, c.globalScope):
    # for ifNode in node.ifStmt.stmtList:
      # c.handleInnerNode(ifNode, parent, c.globalScope, node.ifStmt.stmtList.len, ix)
    return # condition is truthy
  ix = 1


# proc callHandler(c: Compiler, node: Node, scope: var seq[ScopeTable], parent: Node = nil): Node =
#   var callable: Node
#   var stmtScope: ScopeTable
#   let currScope = c.getScope(node.stackIdent, scope)
#   if currScope.st == nil:
#     callable = c.globalScope[node.stackIdent]

#   if not callable.fnFwdDecl: # todo at parser level
#     var ix = 0
#     stmtScope = callable.fnBody.stmtScope
#     case callable.nt
#     of ntFunction:
#       for pName in callable.fnParams.keys():
#         stmtScope[pName].varValue = node.stackArgs[ix]
#         inc ix
#       ix = 1
#       for n in callable.fnBody.stmtList:
#         case n.nt
#         of ntReturn:
#           discard c.getValue(n.returnStmt, stmtScope)
#         else: c.handleInnerNode(n, callable, stmtScope, 0, ix)
#     of ntMixin:
#       for pName in callable.fnParams.keys():
#         stmtScope[pName].varValue = node.stackArgs[ix]
#         inc ix
#       ix = 1
#       for n in callable.fnBody.stmtList:
#         c.handleInnerNode(n, parent, stmtScope, 0, ix)
#     else: discard
#   else:
#     echo node.stackArgs
#     # echo c.getValue(node.stackArgs[0], scope)
#     # let nimCallTypes = strings().get(callable.fnName, strEndsWithFn)
#     # echo nimCallTypes
#     # for i in 0..nimCallTypes.high:
#     #   node.stackArgs 
#     # let x = strings().call(callable.fnName, strEndsWithFn).get()
#     # return newBool(x(node.stackArgs[0], node.stackArgs[1]))
#     # x((c.toString(c.getValue(node.stackArgs[0], scope), scope), c.toString(c.getValue(node.stackArgs[1], scope), scope)))


proc interpret(c: Compiler, node: Node, scope: var seq[ScopeTable]) =
  let
    compileHandler: CompileHandler =
      case node.nt
      of cssSelectors: writeSelector
      of ntVariable:   varDefinition
      of ntAssign:     varAssignment
      of ntCallStack:  fnCallVoid
      of ntCommand:    command
      of ntFunction:   fnDefinition
      of ntCondStmt:   ifCondition
      of ntImport:     importModule
      else:
        echo node
        nil
  if likely(compileHandler != nil):
    compileHandler(c, node, scope)
  # else:


proc len*(c: Compiler): int = c.program.nodes.len

proc newCompiler*(p: Stylesheet, minify = false, imports: Stylesheets = nil): Compiler =
  var c = Compiler(program: p, minify: minify, stylesheets: imports, globalScope: ScopeTable())
  when compileOption("app", "console"):
    c.logger = Logger(filePath: p.sourcePath)
  if not minify:
    c.strCL = spaces(1) & c.strCL & c.strNL
    c.strCR = c.strCR & c.strNL
  else:
    c.strNL = ""
  var localScope = newSeq[ScopeTable]()
  # localScope.add(c.globalScope)
  for i in 0..c.program.nodes.high:
    c.interpret(c.program.nodes[i], localScope)
  result = c

  # var info = SourceInfo()
  # info.newLine("test.sass", 11)
  # info.addSegment(0, 0)
  # info.newLine("test.sass", 13)
  # info.addSegment(0, 0)
  # info.newLine("test.sass", 14)
  # info.addSegment(0, 0)
  # echo toJson(info.toSourceMap("test.css"))
  # echo p.nodes
  # setLen strNL, 0
  # setLen strCL, 0
  # setLen strCR, 0
  if unlikely(c.hasErrors):
    setLen(c.css, 0)

proc toCSS*(p: Stylesheet, minify = false): string =
  newCompiler(p, minify, nil).getCSS