# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import pkg/[jsony, stashtable]
import std/[tables, strutils, macros, sequtils, json,
          algorithm, oids, hashes, terminal, threadpool, enumutils]
import ./ast, ./sourcemap, ./logging

type
  Warning* = tuple[msg: string, line, col: int]
  Compiler* = ref object
    css*, deferred, deferredProps: string
    program: Stylesheet
    sourceMap: SourceInfo
    minify: bool
    stack: Table[int, Node]
    warnings*: seq[Warning]
    strCL: string = "{"
    strCR: string = "}"
    strNL: string = "\n"
    stylesheets: Stylesheets
    when compileOption("app", "console"):
      logger*: Logger

# var strNL, strCL, strCR: string

# forward declaration
proc write(c: Compiler, node: Node, scope: ScopeTable = nil, data: Node = nil)
proc getSelectorGroup(c: Compiler, node: Node, scope: ScopeTable = nil, parent: Node = nil): string
proc handleInnerNode(c: Compiler, node, parent: Node, scope: ScopeTable = nil, len: int, ix: var int)
proc handleCallStack(c: Compiler, node: Node, scope: ScopeTable): Node
proc getValue(c: Compiler, v: Node, scope: ScopeTable): Node


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
          add result, "$1[$2]($3)" % [$(node.callNode.varValue.nt), "mix", $(node.callNode.varValue.arrayItems.len)]
        of ntObject:
          add result, "$1($2)" % [$(node.callNode.varValue.nt), $(node.callNode.varValue.pairsVal.len)]
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

proc toString(c: Compiler, v: Node, scope: ScopeTable = nil): string =
  # Return stringified version of `v`
    result =
      case v.nt
      of ntString: v.sVal
      of ntFloat:  $(v.fVal)
      of ntInt:    $(v.iVal)
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
            x = walkAccessorStorage(v.callNode.accessorStorage, v.callNode.accessorKey, scope)
            return c.getValue(x, scope)  
          try:
            # handle `ntObject` storages
            x = walkAccessorStorage(v.callNode.accessorStorage, v.callNode.accessorKey, scope)
            result = c.getValue(x, scope)
          except KeyError as e:
            newError(c.logger, internalError, 0, 0, true, e.msg)
        of ntVariable:
          handleVariableValue(v.callNode, scope)
        of ntReturn:
          result = c.handleCallStack(v.callNode, scope)
        else: discard
    else:
      return c.getValue(scope[v.callIdent], nil)
  of ntCallStack:
    result = c.handleCallStack(v, scope)
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

proc getProperty(c: Compiler, n: Node, k: string, len: int, scope: ScopeTable, ix: var int): string =
  # Get pairs of `key`:`value`;
  var
    ii = 1
    # vLen = n.pVal.len
  if c.minify:
    add result, k & ":"
  else:
    add result, spaces(2) & k & ":" & spaces(1)
  # for val in n.pVal:
  #   add result, c.getValue(val, scope)
  #   if vLen != ii:
  #     add result, spaces(1)
  #   inc ii
  add result, c.getValue(n.pVal, scope)
  if ix < len:
    add result, ";"
  add result, c.strNL # add \n if not minified
  inc ix

# Writers
include ./handlers/[wCond, wFor]

proc getSelectorGroup(c: Compiler, node: Node,
                  scope: ScopeTable = nil, parent: Node = nil): string =
  # Write CSS selectors and properties
  var ix = 1
  if likely(node.innerNodes.len > 0):
    for innerKey, innerNode in node.innerNodes:
      c.handleInnerNode(innerNode, node, scope, node.innerNodes.len, ix)
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

proc handleImportStmt(c: Compiler, node: Node, scope: ScopeTable) =
  if likely(c.stylesheets != nil):
    for fpath in node.modules:
      c.stylesheets.withValue(fpath):
        for node in value[].nodes:
          c.write(node, scope)

proc handleCommand(c: Compiler, node: Node, scope: ScopeTable = nil) =
  case node.cmdIdent
  of cmdEcho:
    let meta = " (" & $(node.cmdMeta.line) & ":" & $(node.cmdMeta.pos) & ") "
    case node.cmdValue.nt:
    of ntInfix:
      let output = c.evalInfix(node.cmdValue.infixLeft, node.cmdValue.infixRight, node.cmdValue.infixOp, scope)
      stdout.styledWriteLine(fgGreen, "Debug", fgDefault, meta, fgDefault,
                        getTypeInfo(node.cmdValue) & "\n" & $(output))
    of ntMathStmt:
      let
        total =
          c.evalMathInfix(node.cmdValue.mathLeft, node.cmdValue.mathRight,
            node.cmdValue.mathInfixOp, scope)
        output =
          if total.nt == ntInt: $(total.iVal)
          else: $(total.fVal)
      stdout.styledWriteLine(fgGreen, "Debug", fgDefault, meta, fgDefault,
                        getTypeInfo(node.cmdValue) & "\n" & $(output))
    # of ntInfo:
      # stdout.styledWriteLine(fgGreen, "Debug", fgDefault, meta, fgMagenta,
                            # "[[" & $(node.cmdValue.nodeType) & "]]")
    else:
      let varValue = c.getValue(node.cmdValue, scope)
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
                          getTypeInfo(node.cmdValue) & "\n", fgDefault, output)

proc handleCallStack(c: Compiler, node: Node, scope: ScopeTable): Node =
  var
    callable: Node
    stmtScope: ScopeTable
  if scope != nil:
    if scope.hasKey(node.stackIdent):
      callable = scope[node.stackIdent]
  if callable == nil:
    callable = c.program.stack[node.stackIdent]
  stmtScope = callable.fnBody.stmtScope
  case callable.nt
  of ntFunction:
    var ix = 0
    for pName in callable.fnParams.keys():
      stmtScope[pName].varValue = node.stackArgs[ix]
      inc ix
    ix = 1
    for n in callable.fnBody.stmtList:
      case n.nt
      of ntReturn:
        return c.getValue(n.returnStmt, stmtScope)
      else: c.handleInnerNode(n, callable, stmtScope, 0, ix)
  else: discard

proc handleInnerNode(c: Compiler, node, parent: Node,
                    scope: ScopeTable = nil, len: int, ix: var int) =
  case node.nt:
  of ntProperty:
    if parent == nil:
      add c.deferredProps, c.getProperty(node, node.pName, len, scope, ix)
    else:
      parent.properties[node.pName] = node
  of ntClassSelector, ntTagSelector, ntIDSelector, ntRoot, ntUniversalSelector:
    if parent == nil:
      add c.css, c.getSelectorGroup(node, scope)
    else:
      add c.deferred, c.getSelectorGroup(node, scope)
    if unlikely(node.pseudo.len > 0):
      for k, pseudoNode in node.pseudo:
        add c.deferred, c.getSelectorGroup(pseudoNode, scope, node)
  of ntForStmt:
    c.handleForStmt(node, parent, scope)
  of ntCondStmt:
    c.handleCondStmt(node, parent, scope)
  of ntCaseStmt:
    c.handleCaseStmt(node, parent, scope)
  of ntExtend:
    for eKey, eProp in node.extendProps:
      add c.css, c.getProperty(eProp, eKey, node.extendProps.len, scope, ix)
  of ntImport:
    c.handleImportStmt(node, scope)
  of ntCommand:
    c.handleCommand(node, scope)
  of ntCallStack:
    discard c.handleCallStack(node, scope)
  of ntVariable:
    case node.varValue.nt:
    of ntMathStmt:
      node.varValue.mathResult = c.evalMathInfix(node.varValue.mathLeft, node.varValue.mathRight, node.varValue.mathInfixOp, scope)
    else: discard
  else: discard

proc write(c: Compiler, node: Node, scope: ScopeTable = nil, data: Node = nil) =
  case node.nt:
  of ntClassSelector, ntTagSelector, ntIDSelector, ntRoot, ntUniversalSelector:
    add c.css, c.getSelectorGroup(node, scope)
    if unlikely(node.pseudo.len > 0):
      for k, pseudoNode in node.pseudo:
        add c.css, c.getSelectorGroup(pseudoNode, scope, node) 
  of ntForStmt:
    c.handleForStmt(node, nil, scope)
  of ntCondStmt:
    c.handleCondStmt(node, nil, scope)
  of ntCaseStmt:
    c.handleCaseStmt(node, nil, scope)
  of ntImport:
    c.handleImportStmt(node, scope)
  of ntCommand:
    c.handleCommand(node)
  of ntCallStack:
    discard c.handleCallStack(node, scope)
  of ntVariable:
    case node.varValue.nt:
    of ntMathStmt:
      node.varValue.mathResult = c.evalMathInfix(node.varValue.mathLeft, node.varValue.mathRight, node.varValue.mathInfixOp, scope)
    else: discard
  else: discard

proc len*(c: Compiler): int = c.program.nodes.len

proc newCompiler*(p: Stylesheet, minify = false, imports: Stylesheets = nil): Compiler =
  var c = Compiler(program: p, minify: minify, stylesheets: imports)
  when compileOption("app", "console"):
    c.logger = Logger(filePath: p.sourcePath)
  if not minify:
    c.strCL = spaces(1) & c.strCL & c.strNL
    c.strCR = c.strCR & c.strNL
  else:
    c.strNL = ""
  # var info = SourceInfo()
  # info.newLine("test.sass", 11)
  # info.addSegment(0, 0)
  # info.newLine("test.sass", 13)
  # info.addSegment(0, 0)
  # info.newLine("test.sass", 14)
  # info.addSegment(0, 0)
  # echo toJson(info.toSourceMap("test.css"))
  # echo p.nodes
  for i in 0..c.program.nodes.high:
    c.write(c.program.nodes[i])
  result = c
  # setLen strNL, 0
  # setLen strCL, 0
  # setLen strCR, 0
  if unlikely(c.hasErrors):
    setLen(c.css, 0)

proc toCSS*(p: Stylesheet, minify = false): string =
  newCompiler(p, minify, nil).getCSS