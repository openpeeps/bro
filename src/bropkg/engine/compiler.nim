# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro


import std/[tables, strutils, macros, sequtils, json]
import ./ast, ./sourcemap, ./logging, ./eval

when not defined release:
  import std/jsonutils

type
  Warning* = tuple[msg: string, line, col: int]
  Compiler* = ref object
    css*: string
    program: Program
    sourceMap: SourceInfo
    minify: bool
    warnings*: seq[Warning]

var strNL, strCL, strCR: string

# forward defintion
proc write(c: var Compiler, node: Node, scope: ScopeTable = nil, data: Node = nil, parentSelector = "")
proc writeSelector(c: var Compiler, node: Node, scope: ScopeTable = nil, data: Node = nil, parentSelector = "")
proc writeClass(c: var Compiler, node: Node, scope: ScopeTable)
proc handleChildNodes(c: var Compiler, node: Node, scope: ScopeTable = nil,
                      skipped: var bool, length: int)

proc getCSS*(c: Compiler): string =
  result = c.css

when not defined release:
  proc `$`(node: Node): string =
    # print nodes while in dev mode
    result = pretty(node.toJson(), 2)

template writeKeyValue(val: string, i: int) =
  add c.css, k & ":" & val
  if length != i:
    add c.css, ";"

proc prefix(node: Node): string =
  result =
    case node.nt
    of NTClassSelector: "." & node.ident
    of NTIDSelector: "#" & node.ident
    else: node.ident

proc getOtherParents(node: Node, childSelector: string): string =
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

proc writeVal(c: var Compiler, val: Node, scope: ScopeTable, isHexColorStripHash = false) =
  case val.nt
  of NTString:
    # add c.css, "\"" & val.sVal & "\""
    add c.css, val.sVal
  of NTFloat:
    add c.css, $val.fVal
  of NTInt:
    add c.css, $val.iVal
  of NTColor:
    if not isHexColorStripHash:
      add c.css, val.cVal
    else:
      add c.css, val.cVal[1..^1]
  of NTJsonValue:
    case val.jsonVal.kind:
    of JString:
      add c.css, val.jsonVal.getStr
    of JInt:
      add c.css, $(val.jsonVal.getInt)
    else: discard # todo compiler error when JObject, JArray
  of NTCall:
    if val.callNode.varValue != nil:
      case val.callNode.varValue.nt:
      of NTJsonValue:
        c.writeVal(val.callNode.varValue, nil, isHexColorStripHash)
      else:
        c.writeVal(val.callNode.varValue.val, nil, isHexColorStripHash)
    else:
      if scope.hasKey(val.callNode.varName):
        case scope[val.callNode.varName].varValue.nt:
        of NTJsonValue:
          c.writeVal(scope[val.callNode.varName].varValue, nil, isHexColorStripHash)
        else:
          c.writeVal(scope[val.callNode.varName].varValue.val, nil, isHexColorStripHash)
    discard
  else: discard

proc writeProps(c: var Compiler, n: Node, k: string, i: var int, length: int, scope: ScopeTable) =
  var ii = 1
  var vLen = n.pVal.len
  if c.minify:
    add c.css, k & ":"
  else:
    add c.css, spaces(2) & k & ":" & spaces(1)
  for val in n.pVal:
    c.writeVal(val, scope)
    if vLen != ii:
      add c.css, spaces(1)
    inc ii
  if i != length:
    add c.css, ";"
  add c.css, strNL # if not minifying
  inc i

proc handleForStmt(c: var Compiler, node: Node, scope: ScopeTable) =
  case node.inItems.callNode.nt:
  of NTVariable:
    let items = node.inItems.callNode.varValue.arrayVal
    for i in 0 .. items.high:
      node.forScopes[node.forItem.varName].varValue = items[i]
      for ii in 0 .. node.forBody.high:
        c.write(node.forBody[ii], node.forScopes, items[i])
  of NTJsonValue:
    for item in items(node.inItems.callNode.jsonVal):
      node.forScopes[node.forItem.varName].varValue = newJson item
      for i in 0 .. node.forBody.high:
        c.write(node.forBody[i], node.forScopes, newJson item)
  else: discard

proc handleCondStmt(c: var Compiler, node: Node, scope: ScopeTable) =
  if evalInfix(node.ifInfix.infixLeft, node.ifInfix.infixRight, node.ifInfix.infixOp, scope):
    var ix = 0
    var skipped: bool
    for ii in 0 .. node.ifBody.high:
      # c.write(node.ifBody[ii], scope)
      # c.handleChildNodes(node.ifBody[ii], scope, skipped,)
      case node.ifBody[ii].nt:
      of NTProperty:
        c.writeProps(node.ifBody[ii], node.ifBody[ii].pName, ix, node.ifBody.len, scope)
      of NTCondStmt:
        discard
      else:
        # todo handle nested selectors
        discard
  elif node.elifNode.len != 0:
    for elifNode in node.elifNode:
      if evalInfix(elifNode.infix.infixLeft, elifNode.infix.infixRight, elifNode.infix.infixOp, scope):
        var ix = 0
        for ii in 0 .. elifNode.body.high:
          case elifNode.body[ii].nt
          of NTProperty:
            c.writeProps(elifNode.body[ii], elifNode.body[ii].pName, ix, elifNode.body.len, scope)
          of NTCondStmt:
            discard
          else:
            # todo handle nested selectors
            discard

proc handleAOT(c: var Compiler, node: Node, scope: ScopeTable) =
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

include ./compileutils/handleWriteSelector

proc handleCaseStmt(c: var Compiler, node: Node, scope: ScopeTable, data: Node) =
  for i in 0 .. node.caseCond.high:
    if evalInfix(node.caseIdent, node.caseCond[i].condOf, EQ, scope):
      for ii in 0 .. node.caseCond[i].body.high:
        c.write(node.caseCond[i].body[ii], scope)
      return
  for i in 0 .. node.caseElse.high:
    c.write(node.caseElse[i], scope)

proc handleImportStmt(c: var Compiler, node: Node, scope: ScopeTable) =
  for i in 0 .. node.importNodes.high:
    c.write(node.importNodes[i], scope)
    # case node.importNodes[i].nt:
    # of NTClassSelector, NTTagSelector, NTIDSelector, NTRoot:
    #   c.writeSelector(node.importNodes[i])
    # of NTForStmt:
    #   c.handleForStmt(node.importNodes[i], scope)
    # else: discard # todo

proc write(c: var Compiler, node: Node, scope: ScopeTable = nil, data: Node = nil, parentSelector = "") =
  case node.nt:
  of NTClassSelector, NTTagSelector, NTIDSelector, NTRoot:
    c.writeSelector(node, scope, data, parentSelector)
    if unlikely(node.pseudo.len != 0):
      for k, pseudoNode in node.pseudo:
        c.writeSelector(pseudoNode, scope, data)
  of NTForStmt:
    c.handleForStmt(node, scope)
  of NTCondStmt:
    c.handleCondStmt(node, scope)
  of NTCaseStmt:
    c.handleCaseStmt(node, scope, data)
  of NTImport:
    c.handleImportStmt(node, scope)
  of NTCommand:
    case node.cmdIdent
    of cmdEcho:
      discard # todo
      # echo node
  else: discard

proc len*(c: var Compiler): int = c.program.nodes.len

proc newCompiler*(p: Program, outputPath: string, minify = false): Compiler =
  var c = Compiler(program: p, minify: minify)
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