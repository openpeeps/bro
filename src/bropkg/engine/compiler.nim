# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import pkg/jsony
import std/[tables, strutils, macros, json, algorithm, terminal]
import ./ast, ./sourcemap, ./logging, ./eval

type
  Warning* = tuple[msg: string, line, col: int]
  Compiler* = ref object
    css*, deferred, deferredProps: string
    program: Program
    sourceMap: SourceInfo
    minify, sortPropsEnabled: bool
    stack: Table[int, Node]
    warnings*: seq[Warning]

var strNL, strCL, strCR: string

# forward declaration
proc write(c: var Compiler, node: Node, scope: ScopeTable = nil, data: Node = nil)
proc getSelectorGroup(c: var Compiler, node: Node, scope: ScopeTable = nil, parent: Node = nil): string
proc handleInnerNode(c: var Compiler, node, parent: Node, scope: ScopeTable = nil, length: int, ix: var int)
proc handleCallStack(c: var Compiler, node: Node)

proc getTypeInfo(node: Node): string =
  # Return type info for given Node
  case node.nt
  of ntCall:
    if node.callNode != nil:
      case node.callNode.varValue.nt:
      of ntArray:
        add result, "$1[$2]($3)" % [$(node.callNode.varValue.nt), "Mix", $(node.callNode.varValue.itemsVal.len)]
      of ntObject:
        add result: "$1($2)" % [$(node.callNode.varValue.nt), $(node.callNode.varValue.objectFields.len)]
      of ntVarValue:
        add result, $(node.callNode.varValue.val.nt)
      else: discard
    else:
      # todo parameter has no body
      # will need to get the 
      discard
  else: discard

proc getCSS*(c: Compiler): string =
  result = c.css

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
      if unlikely(node.nt == ntPseudoClassSelector):
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
  of ntVarValue:
    s.dumpHook(v.val)
  else: discard

proc getValue(c: var Compiler, val: Node, scope: ScopeTable): string =
  case val.nt
  of ntString:
    add result, val.sVal
  of ntFloat:
    add result, $val.fVal
  of ntInt:
    add result, $val.iVal
  of ntBool:
    add result, $val.bVal
  of ntColor:
    add result, val.cVal
  of ntVarValue:
    add result, c.getValue(val.val, nil)
  of ntArray:
    add result, jsony.toJson(val.itemsVal)
  of ntObject:
    add result, jsony.toJson(val.objectFields)
  of ntStream:
    case val.streamContent.kind:
    of JString:
      add result, val.streamContent.str
    of JInt:
      add result, $(val.streamContent.num)
    of JFloat:
      add result, $(val.streamContent.fnum)
    of JObject, JArray:
      add result, $(val.streamContent)
    of JNull:
      add result, "null"
    of JBool:
      add result, $(val.streamContent.bval)
  of ntInfix:
    add result, $(evalInfix(val.infixLeft, val.infixRight, val.infixOp, scope))
  of ntCall:
    if val.callNode != nil:
      if val.callNode.varValue != nil:
        case val.callNode.varValue.nt:
        of ntStream:
          add result, c.getValue(val.callNode.varValue, nil)
        else:
          add result, c.getValue(val.callNode.varValue, nil)
      else:
        case scope[val.callNode.varName].varValue.nt:
        of ntStream:
          add result, c.getValue(scope[val.callNode.varName].varValue, nil)
        else:
          add result, c.getValue(scope[val.callNode.varName].varValue, nil)
    else:
      add result, c.getValue(scope[val.callIdent], nil)
  of ntCallStack:
    c.handleCallStack(val)
  else: discard

proc getProperty(c: var Compiler, n: Node, k: string, i: var int,
                length: int, scope: ScopeTable): string =
  # Get pairs of `key`:`value`;
  var
    ii = 1
    vLen = n.pVal.len
  if c.minify: add result, k & ":"
  else:
    add result, spaces(2) & k & ":" & spaces(1)
  for val in n.pVal:
    add result, c.getValue(val, scope)
    if vLen != ii:
      add result, spaces(1)
    inc ii
  if i != length:
    add result, ";"
  add result, strNL # add \n if not minified
  inc i

proc handleForStmt(c: var Compiler, node, parent: Node, scope: ScopeTable) =
  # Handle `for` statements
  case node.inItems.callNode.nt:
  of ntVariable:
    let items = node.inItems.callNode.varValue.itemsVal
    var ix = 1
    for i in 0 .. items.high:
      node.forScopes[node.forItem.varName].varValue = items[i]
      for ii in 0 .. node.forBody.stmtList.high:
        c.handleInnerNode(node.forBody.stmtList[ii], parent, node.forScopes, node.forBody.stmtList.len, ix)
        # c.write(node.forBody[ii], node.forScopes, items[i])
  of ntStream:
    var ix = 1
    for item in items(node.inItems.callNode.streamContent):
      node.forScopes[node.forItem.varName].varValue = newStream item
      for i in 0 .. node.forBody.stmtList.high:
        # c.write(node.forBody[i], node.forScopes, newJson item)
        c.handleInnerNode(node.forBody.stmtList[i], parent, node.forScopes, node.forBody.stmtList.len, ix)
  else: discard

proc handleExtendAOT(c: var Compiler, node: Node, scope: ScopeTable) =
  ## TODO collect scope data
  for childSelector in node.extendBy:
    for aot in c.program.selectors[childSelector].aotStmts:
      case aot.nt:
      of ntInfix:
        if not evalInfix(aot.infixLeft, aot.infixRight, aot.infixOp, scope):
          node.extendBy.delete(node.extendBy.find(childSelector))
      of ntForStmt:
        discard # todo
      else: discard

# Writers
include ./handlers/[wCond]

proc getSelectorGroup(c: var Compiler, node: Node,
                  scope: ScopeTable = nil, parent: Node = nil): string =
  # Write CSS selectors and properties
  if node.extendBy.len != 0:
    c.handleExtendAOT(node, scope)
  var i = 1
  if likely(node.innerNodes.len != 0):
    for innerKey, innerNode in node.innerNodes:
      c.handleInnerNode(innerNode, node, scope, node.innerNodes.len, i)
  var
    skipped: bool
    length = node.properties.len
  if length != 0:
    if node.parents.len != 0:
      add result, node.parents.join(" ") & spaces(1) & node.ident
    else:
      add result, node.ident
    for idConcat in node.identConcat:
      case idConcat.nt
      of ntCall:
        var scopeVar: Node
        if idConcat.callNode.varValue != nil:
          add result, c.getValue(idConcat, nil)
        else:
          scopeVar = scope[idConcat.callNode.varName]
          var varValue = scopeVar.varValue
          case varValue.val.nt
          of ntColor:
            # todo handle colors at parser level
            idConcat.callNode.varValue = varValue
            add result, c.getValue(idConcat, nil)
          else:
            idConcat.callNode.varValue = varValue
            add result, c.getValue(idConcat, nil)
      of ntString, ntInt, ntFloat, ntBool:
        add result, c.getValue(idConcat, nil)
      else: discard
    add result, strCL # {
    i = 1
    if length != 1 and c.sortPropsEnabled: node.properties.sort(system.cmp) # todo make it optional
    for propName, propNode in node.properties:
      add result, c.getProperty(propNode, propName, i, length, scope)
    add result, strCR # }
    add result, c.deferred
    setLen c.deferred, 0
    # add c.css, c.deferred
    # setLen(c.deferred, 0)

# proc writeClass(c: var Compiler, node: Node, scope: ScopeTable) =
#   c.getSelectorGroup(node)
#   if unlikely(node.pseudo.len != 0):
#     for k, pseudoNode in node.pseudo:
#       c.getSelectorGroup(pseudoNode, scope)

proc handleImportStmt(c: var Compiler, node: Node, scope: ScopeTable) =
  for i in 0 .. node.importNodes.high:
    c.write(node.importNodes[i], scope)

proc handleCommand(c: var Compiler, node: Node, scope: ScopeTable = nil) =
  case node.cmdIdent
  of cmdEcho:
    let meta = " (" & $(node.cmdMeta.line) & ":" & $(node.cmdMeta.pos) & ") "
    case node.cmdValue.nt:
    of ntInfix:
      let output = evalInfix(node.cmdValue.infixLeft, node.cmdValue.infixRight, node.cmdValue.infixOp, scope)
      stdout.styledWriteLine(fgGreen, "Debug", fgDefault, meta, fgDefault, getTypeInfo(node.cmdValue) & "\n" & $(output))
    of ntInfo:
      stdout.styledWriteLine(fgGreen, "Debug", fgDefault, meta, fgMagenta, "[[" & $(node.cmdValue.nodeType) & "]]")
    else:
      let output = c.getValue(node.cmdValue, scope)
      stdout.styledWriteLine(fgGreen, "Debug", fgDefault, meta, fgMagenta, getTypeInfo(node.cmdValue) & "\n", fgDefault, output)

proc handleReturn(c: var Compiler, node: Node, scope: ScopeTable) =
    # echo node
    # echo scope
    discard

proc handleCallStack(c: var Compiler, node: Node) =
  # echo c.program.stack.hasKey(node.callStackIdent)
  let callable = c.program.stack[node.callStackIdent]
  case callable.nt
  of ntFunction:
    var i = 0
    var scope = ScopeTable() 
    for pName in callable.fnParams.keys():
      scope[pName] = node.callStackArgs[i]
      inc i
    i = 0
    for n in callable.fnBody.stmtList:
      case n.nt
      of ntReturn:
        c.handleInnerNode(n, callable, scope, 0, i)
        return
      else: c.handleInnerNode(n, callable, scope, 0, i)
  else: discard

proc handleInnerNode(c: var Compiler, node, parent: Node,
                    scope: ScopeTable = nil, length: int, ix: var int) =
  # echo node
  case node.nt:
  of ntProperty:
    if parent == nil:
      add c.deferredProps, c.getProperty(node, node.pName, ix, length, scope)
    else:
      parent.properties[node.pName] = node
  of ntClassSelector, ntTagSelector, ntIDSelector, ntRoot:
    # echo parent == nil
    if parent == nil:
      add c.css, c.getSelectorGroup(node, scope)
    else:
      add c.deferred, c.getSelectorGroup(node, scope)
    if unlikely(node.pseudo.len != 0):
      for k, pseudoNode in node.pseudo:
        add c.deferred, c.getSelectorGroup(pseudoNode, scope)
  of ntForStmt:
    c.handleForStmt(node, parent, scope)
  of ntCondStmt:
    c.handleCondStmt(node, parent, scope)
  of ntCaseStmt:
    c.handleCaseStmt(node, scope)
  of ntExtend:
    for eKey, eProp in node.extendProps:
      var ix = 0
      add c.css, c.getProperty(eProp, eKey, ix, node.extendProps.len, scope)
  of ntImport:
    c.handleImportStmt(node, scope)
  of ntCommand:
    c.handleCommand(node, scope)
  of ntReturn:
    c.handleReturn(node, scope)
  else: discard

proc write(c: var Compiler, node: Node, scope: ScopeTable = nil, data: Node = nil) =
  case node.nt:
  of ntClassSelector, ntTagSelector, ntIDSelector, ntRoot:
    add c.css, c.getSelectorGroup(node, scope)
    if unlikely(node.pseudo.len != 0):
      for k, pseudoNode in node.pseudo:
        add c.css, c.getSelectorGroup(pseudoNode, scope)
  of ntForStmt:
    c.handleForStmt(node, nil, scope)
  of ntCondStmt:
    c.handleCondStmt(node, nil, scope)
  of ntCaseStmt:
    c.handleCaseStmt(node, scope)
  of ntImport:
    c.handleImportStmt(node, scope)
  of ntCommand:
    c.handleCommand(node)
  of ntCallStack:
    c.handleCallStack(node)
  else: discard

proc len*(c: var Compiler): int = c.program.nodes.len

proc newCompiler*(p: Program, outputPath: string, minify = false, enableSortingProps = true): Compiler =
  var c = Compiler(program: p, minify: minify, sortPropsEnabled: enableSortingProps)
  strCL = "{"
  strCR = "}"
  if minify == false:
    strNL = "\n"
    strCL = spaces(1) & strCL & strNL
    strCR = strCR & strNL
  # var info = SourceInfo()
  # info.newLine("test.sass", 11)
  # info.addSegment(0, 0)
  # info.newLine("test.sass", 13)
  # info.addSegment(0, 0)
  # info.newLine("test.sass", 14)
  # info.addSegment(0, 0)
  # echo toJson(info.toSourceMap("test.css"))
  # echo p.nodes
  for i in 0.. c.program.nodes.high:
    c.write(c.program.nodes[i])
  result = c
  setLen strNL, 0
  setLen strCL, 0
  setLen strCR, 0