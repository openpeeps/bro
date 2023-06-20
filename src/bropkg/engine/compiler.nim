# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro


import std/[tables, strutils, macros, json, algorithm]
import ./ast, ./sourcemap, ./logging, ./eval

when not defined release:
  import std/jsonutils

type
  Warning* = tuple[msg: string, line, col: int]
  Compiler* = ref object
    css*, deferred, deferredProps: string
    program: Program
    sourceMap: SourceInfo
    minify, sortPropsEnabled: bool
    warnings*: seq[Warning]

var strNL, strCL, strCR: string

# forward defintion
proc write(c: var Compiler, node: Node, scope: ScopeTable = nil, data: Node = nil)
proc getSelectorGroup(c: var Compiler, node: Node, scope: ScopeTable = nil, parent: Node = nil): string
# proc writeClass(c: var Compiler, node: Node, scope: ScopeTable)
proc handleInnerNode(c: var Compiler, node, parent: Node, scope: ScopeTable = nil,
                    length: int, ix: var int)

proc getCSS*(c: Compiler): string =
  result = c.css

when not defined release:
  proc `$`(node: Node): string =
    # print nodes while in dev mode
    result = pretty(node.toJson(), 2)

proc prefix(node: Node): string =
  # Prefix CSS selector, `.myclass` for NTClassSelector,
  # `#myId` for `NTIDSelector` and so on
  result =
    case node.nt
    of NTClassSelector: "." & node.ident
    of NTIDSelector: "#" & node.ident
    else: node.ident

proc getOtherParents(node: Node, childSelector: string): string =
  # Retrieve all CSS sibling selectors
  var res: seq[string]
  for parent in node.parents:
    if likely(node.nested == false):
      if unlikely(node.nt == NTPseudoClassSelector):
        add res, parent & ":" & childSelector
      else:
        add res, parent & " " & childSelector
    else:
      add res, parent & childSelector
  result = res.join(",")

proc getValue(c: var Compiler, val: Node, scope: ScopeTable,
              isHexColorStripHash = false): string =
  # Unpack and write values
  case val.nt
  of NTString:
    # add c.css, "\"" & val.sVal & "\""
    add result, val.sVal
  of NTFloat:
    add result, $val.fVal
  of NTInt:
    add result, $val.iVal
  of NTColor:
    if not isHexColorStripHash:
      add result, val.cVal
    else:
      add result, val.cVal[1..^1]
  of NTJsonValue:
    case val.jsonVal.kind:
    of JString:
      add result, val.jsonVal.getStr
    of JInt:
      add result, $(val.jsonVal.getInt)
    else: discard # todo compiler error when JObject, JArray
  of NTCall:
    if val.callNode.varValue != nil:
      case val.callNode.varValue.nt:
      of NTJsonValue:
        add result, c.getValue(val.callNode.varValue, nil, isHexColorStripHash)
      else:
        add result, c.getValue(val.callNode.varValue.val, nil, isHexColorStripHash)
    else:
      if scope.hasKey(val.callNode.varName):
        case scope[val.callNode.varName].varValue.nt:
        of NTJsonValue:
          add result, c.getValue(scope[val.callNode.varName].varValue, nil, isHexColorStripHash)
        else:
          add result, c.getValue(scope[val.callNode.varName].varValue.val, nil, isHexColorStripHash)
    discard
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
  of NTVariable:
    let items = node.inItems.callNode.varValue.arrayVal
    var ix = 1
    for i in 0 .. items.high:
      node.forScopes[node.forItem.varName].varValue = items[i]
      for ii in 0 .. node.forBody.high:
        c.handleInnerNode(node.forBody[ii], parent, node.forScopes, node.forBody.len, ix)
        # c.write(node.forBody[ii], node.forScopes, items[i])
  of NTJsonValue:
    for item in items(node.inItems.callNode.jsonVal):
      node.forScopes[node.forItem.varName].varValue = newJson item
      for i in 0 .. node.forBody.high:
        c.write(node.forBody[i], node.forScopes, newJson item)
  else: discard

proc handleExtendAOT(c: var Compiler, node: Node, scope: ScopeTable) =
  ## TODO collect scope data
  for childSelector in node.extendBy:
    for aot in c.program.selectors[childSelector].aotStmts:
      case aot.nt:
      of NTInfix:
        if not evalInfix(aot.infixLeft, aot.infixRight, aot.infixOp, scope):
          node.extendBy.delete(node.extendBy.find(childSelector))
      of NTForStmt:
        discard # todo
      else: discard

proc handleCondStmt(c: var Compiler, node, parent: Node, scope: ScopeTable) =
  # Handle `if`, `elif`, `else` statements
  var tryElse: bool
  if evalInfix(node.ifInfix.infixLeft, node.ifInfix.infixRight, node.ifInfix.infixOp, scope):
    var ix = 0
    for ifNode in node.ifBody:
      c.handleInnerNode(ifNode, parent, scope, node.ifBody.len, ix)
  elif node.elifNode.len != 0:
    for elifNode in node.elifNode:
      if evalInfix(elifNode.infix.infixLeft, elifNode.infix.infixRight, elifNode.infix.infixOp, scope):
        var ix = 0
        for elifNode in elifNode.body:
          c.handleInnerNode(elifNode, parent, scope, node.elifNode.len, ix)
        tryElse = false
      else:
        tryElse = true
  if node.elseBody.len != 0 and tryElse:
    var ix = 0
    for elseNode in node.elseBody:
      c.handleInnerNode(elseNode, parent, scope, node.elseBody.len, ix)

proc handleCaseStmt(c: var Compiler, node: Node, scope: ScopeTable) =
  # Handle `case` statements
  for i in 0 .. node.caseCond.high:
    if evalInfix(node.caseIdent, node.caseCond[i].condOf, EQ, scope):
      for ii in 0 .. node.caseCond[i].body.high:
        c.write(node.caseCond[i].body[ii], scope)
      return
  for i in 0 .. node.caseElse.high:
    c.write(node.caseElse[i], scope)

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
      of NTCall:
        var scopeVar: Node
        if idConcat.callNode.varValue != nil:
          add result, c.getValue(idConcat, nil)
        else:
          scopeVar = scope[idConcat.callNode.varName]
          var varValue = scopeVar.varValue
          case varValue.val.nt
          of NTColor:
            # todo handle colors at parser level
            idConcat.callNode.varValue = varValue
            add result, c.getValue(idConcat, nil, varValue.val.cVal[0] == '#')
          else:
            idConcat.callNode.varValue = varValue
            add result, c.getValue(idConcat, nil)
      of NTString, NTInt, NTFloat, NTBool:
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

proc handleInnerNode(c: var Compiler, node, parent: Node,
                    scope: ScopeTable = nil, length: int, ix: var int) =
  case node.nt:
  of NTProperty:
    if parent == nil:
      add c.deferredProps, c.getProperty(node, node.pName, ix, length, scope)
    else:
      parent.properties[node.pName] = node
  of NTClassSelector, NTTagSelector, NTIDSelector, NTRoot:
    add c.deferred, c.getSelectorGroup(node, scope)
    if unlikely(node.pseudo.len != 0):
      for k, pseudoNode in node.pseudo:
        add c.deferred, c.getSelectorGroup(pseudoNode, scope)
  of NTForStmt:
    c.handleForStmt(node, parent, scope)
  of NTCondStmt:
    c.handleCondStmt(node, parent, scope)
  of NTCaseStmt:
    c.handleCaseStmt(node, scope)
  of NTExtend:
    for eKey, eProp in node.extendProps:
      var ix = 0
      add c.css, c.getProperty(eProp, eKey, ix, node.extendProps.len, scope)
  of NTImport:
    c.handleImportStmt(node, scope)
  else: discard

proc write(c: var Compiler, node: Node, scope: ScopeTable = nil, data: Node = nil) =
  case node.nt:
  of NTClassSelector, NTTagSelector, NTIDSelector, NTRoot:
    add c.css, c.getSelectorGroup(node, scope)
    if unlikely(node.pseudo.len != 0):
      for k, pseudoNode in node.pseudo:
        add c.css, c.getSelectorGroup(pseudoNode, scope)
  of NTForStmt:
    c.handleForStmt(node, nil, scope)
  of NTCondStmt:
    c.handleCondStmt(node, nil, scope)
  of NTCaseStmt:
    c.handleCaseStmt(node, scope)
  of NTImport:
    c.handleImportStmt(node, scope)
  of NTCommand:
    case node.cmdIdent
    of cmdEcho:
      discard # todo
      # echo node
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