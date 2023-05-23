# Bro aka NimSass
# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro


import std/[tables, strutils]
import ./ast, ./sourcemap, ./logging

when not defined release:
  import std/[json, jsonutils]

type
  Warning* = tuple[msg: string, line, col: int]
  Compiler* = ref object
    css*: string
    program: Program
    sourceMap: SourceInfo
    minify: bool
    warnings*: seq[Warning]

# forward defintion
proc write(c: var Compiler, node: Node, scope: OrderedTableRef[string, Node] = nil, data: Node = nil)
proc writeSelector(c: var Compiler, node: Node, scope: OrderedTableRef[string, Node] = nil, data: Node = nil)
proc writeClass(c: var Compiler, node: Node)

# proc getCss*(c: Compiler): string =
  # result = c.css

when not defined release:
  proc `$`(node: Node): string =
    # print nodes while in dev mode
    result = pretty(node.toJson(), 2)

proc clean*(c: var Compiler) =
  # reset c.css
  discard

template startCurly() =
  if c.minify:
    add c.css, "{"
  else:
    add c.css, " {\n"

template endCurly() =
  if c.minify:
    add c.css, "}"
  else:
    add c.css, "}\n"

template writeKeyValue(val: string, i: int) =
  add c.css, k & ":" & val
  if length != i:
    add c.css, ";"

proc getOtherParents(node: Node, childSelector: string): string =
  var res: seq[string]
  for parent in node.parents:
    if likely(node.nested == false):
      if unlikely(node.nt == NTPseudoClass):
        add res, parent & ":" & childSelector
      else:
        add res, parent & " " & childSelector
    else:
      add res, parent & childSelector
  result = res.join(",")

proc writeVal(c: var Compiler, val: Node, scope: OrderedTableRef[string, Node], isHexColorStripHash = false) =
  case val.nt
  of NTString:
    add c.css, val.sVal
  of NTFloat:
    add c.css, val.fVal
  of NTInt:
    add c.css, val.iVal
  of NTColor:
    if not isHexColorStripHash:
      add c.css, val.cVal
    else:
      add c.css, val.cVal[1..^1]
  of NTCall:
    if val.callNode.varValue != nil:
      c.writeVal(val.callNode.varValue.val, nil, isHexColorStripHash)
    else:
      if scope.hasKey(val.callNode.varName):
        c.writeVal(scope[val.callNode.varName].varValue.val, nil, isHexColorStripHash)
    discard
  else: discard

proc writeProps(c: var Compiler, n: Node, k: string, i: var int,
              length: int, scope: OrderedTableRef[string, Node]) =
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
  if not c.minify:
    add c.css, "\n"
  inc i

proc writeSelector(c: var Compiler, node: Node, scope: OrderedTableRef[string, Node] = nil, data: Node = nil) =
  var skipped: bool
  let length = node.props.len
  if node.multiIdent.len == 0 and node.parents.len == 0:
    add c.css, node.ident
    for identConcat in node.identConcat:
      if identConcat.nt == NTCall:
        let scopeVar = scope[identConcat.callNode.varName]
        var varValue = scopeVar.varValue
        if unlikely(varValue.val.nt == NTColor):
          # check if given variable contains a hex based color,
          # in this case will remove the hash ta
          identConcat.callNode.varValue = varValue
          c.writeVal(identConcat, nil, varValue.val.cVal[0] == '#')
        else:
          identConcat.callNode.varValue = varValue
          c.writeVal(identConcat, nil)
      elif identConcat.nt in {NTString, NTInt, NTFloat, NTBool}:
        c.writeVal(identConcat, nil)

  elif node.parents.len != 0:
    add c.css, node.getOtherParents(node.ident)
  else:
    add c.css, node.ident & "," & node.multiIdent.join(",")
  startCurly()
  var i = 1
  for k, v in node.props.pairs():
    case v.nt:
    of NTProperty:
      c.writeProps(v, k, i, length, scope)
    of NTSelectorClass:
      if not skipped:
        endCurly()
        skipped = true
      c.writeClass(v)
    of NTPseudoClass:
      if not skipped:
        endCurly()
        skipped = true
      c.writeSelector(v)
    of NTExtend:
      for eKey, eProp in v.extendProps.pairs():
        var ix = 0
        c.writeProps(eProp, eKey, ix, v.extendProps.len, scope)
    of NTCall:
      discard v.callNode.nt
    of NTForStmt:
      let items = node.inItems.callNode.varValue.arrayVal
      # for x in 0..items.high:
      #   echo x
    else: discard
  if not skipped:
    endCurly()

proc writeClass(c: var Compiler, node: Node) =
  c.writeSelector(node)

proc writeID(c: var Compiler, node: Node) =
  c.writeSelector(node)

proc writeTag(c: var Compiler, node: Node) =
  c.writeSelector(node)

proc write(c: var Compiler, node: Node, scope: OrderedTableRef[string, Node] = nil, data: Node = nil) =
  case node.nt:
  of NTSelectorClass, NTSelectorTag, NTSelectorID, NTRoot:
    c.writeSelector(node, scope, data)
  of NTForStmt:
    let items = node.inItems.callNode.varValue.arrayVal
    for i in 0..items.high:
      for n in node.forBody:
        node.forScopes[node.forItem.varName].varValue = items[i]
        c.write(n, node.forScopes, items[i])
  of NTImport:
    for subNode in node.importNodes:
      case subNode.nt:
      of NTSelectorClass, NTSelectorTag, NTSelectorID, NTRoot:
        c.writeSelector(subNode)
      else: discard 
  else: discard

proc newCompiler*(p: Program, outputPath: string, minify = false) =
  var c = Compiler(program: p, minify: minify)
  # var info = SourceInfo()
  # info.newLine("test.sass", 11)
  # info.addSegment(0, 0)
  # info.newLine("test.sass", 13)
  # info.addSegment(0, 0)
  # info.newLine("test.sass", 14)
  # info.addSegment(0, 0)

  # echo toJson(info.toSourceMap("test.css"))
  for node in c.program.nodes:
    c.write(node)
  writeFile(outputPath, c.css)
  reset c.css

proc newCompilerStr*(p: Program, outputPath: string): string =
  var c = Compiler(program: p)
  for node in c.program.nodes:
    c.write node
  result = c.css