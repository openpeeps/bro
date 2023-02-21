# Bro aka NimSass
# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro

import std/[os, strutils, sequtils, macros, tables,
            memfiles, critbits]
import ./tokens, ./ast, ./resolver, ./memtable, ./logging
import ./properties

import std/[threadpool, times]

import pkg/klymene/cli

when not defined release:
  import std/[json, jsonutils] 

export logging

type
  ParserType = enum
    Main
    Partial 

  Warning* = tuple[msg: string, line, col: int]

  PartialFilePath = distinct string

  Importer* = ref object
    partials: OrderedTableRef[int, tuple[indentation: int, sourcePath: string]]
    sources: TableRef[string, MemFile]

  Parser* = object
    lex: Lexer
    prev, curr, next: TokenTuple
    program: Program
    memtable: Memtable
    when compileOption("app", "console"):
      error: seq[Row]
      logger*: Logger
    else:
      error: string
    hasErrors*: bool
    warnings*: seq[Warning]
    imports: Importer
    ptrNodes: Table[string, Node]
    case ptype: ParserType
    of Main:
      projectDirectory: string
    else: discard
    filePath: string

  PrefixFunction = proc(p: var Parser): Node
  PartialChannel = tuple[status: string, program: Program]

# forward definition
proc getPrefix(p: var Parser, kind: TokenKind): PrefixFunction
proc parse(p: var Parser): Node
proc parseVariableCall(p: var Parser): Node
proc partialThread(filePath: string, lastModified: Time): Parser {.thread.}

when compileOption("app", "console"):
  template err(msg: string) =
    let pos = if p.curr.pos == 0: 0 else: p.curr.pos + 1
    add p.error, @[span("Error ($2:$3): $1" % [msg, $p.curr.line, $pos])]

  template err(msg: string, tk: TokenTuple, sfmt: varargs[string]) =
    let pos = if tk.pos == 0: 0 else: tk.pos + 1
    var newRow: Row
    add newRow, span("Error", fgRed, indentSize = 0)
    add newRow, span("(" & $tk.line & ":" & $pos & ")")
    add newRow, span(msg)
    for str in sfmt:
      add newRow, span(str, fgMagenta)
    add p.error, newRow
    add p.error, @[span(p.filePath)]
    return

  proc getError*(p: Parser): seq[Row] =
    result =
      if p.error.len != 0: p.error
      else:
        @[@[span(p.lex.getError)]]

else:
  template err(msg: string) =
    let pos = if tk.pos == 0: 0 else: tk.pos + 1
    p.error = "Error ($2:$3): $1" % [msg, $p.curr.line, $pos]

  template err(msg: string, tk: TokenTuple, sfmt: varargs[string]) =
    var errmsg = msg
    for str in sfmt:
      add errmsg, indent("\"" & str & "\"", 1)  
    let pos = if tk.pos == 0: 0 else: tk.pos + 1 
    p.error = "Error ($2:$3): $1" % [errmsg, $tk.line, $pos]
    return

  proc getError*(p: Parser): string =
    result =
      if p.error.len != 0: p.error
      else: p.lex.getError

proc hasError*(p: Parser): bool =
  result = p.error.len != 0 or p.lex.hasError

proc hasWarnings*(p: Parser): bool =
  result = p.warnings.len != 0

when not defined release:
  proc `$`(node: Node): string =
    # print nodes while in dev mode
    result = pretty(node.toJson(), 2)

macro definePseudoClasses() =
  # https://developer.mozilla.org/en-US/docs/Web/CSS/:host_function
  var pseudoTable = nnkTableConstr.newTree()
  let keys = [("active", 0), ("any-link", 0), ("autofill", 0), ("blank", 0),
    ("checked", 0), ("current", 0), ("default", 0), ("defined", 0), ("dir", 1),
    ("disabled", 0), ("empty", 0), ("enabled", 0), ("first", 0), ("first-child", 0),
    ("focus", 0), ("focus-visible", 0), ("fullscreen", 0), ("future", 0), ("has", -1),
    ("host", -1), ("host-context", 1), ("hover", 0), ("in-range", 0), ("indeterminate", 0),
    ("invalid", 0), ("is", -1), ("lang", 1), ("last-child", 0), ("last-of-type", 0),
    ("left", 0), ("link", 0), ("link", 0), ("local-link", 0), ("modal", 0), ("not", -1),
    ("nth-child", 1), ("nth-col", 1), ("nth-last-child", 1), ("nth-last-col", 1),
    ("nth-last-of-type", 1), ("nth-of-type", 1), ("only-child", 0), ("only-of-type", 0),
    ("optional", 0), ("out-of-range", 0), ("past", 0), ("paused", 0), ("picture-in-picture", 0),
    ("placeholder-shown", 0), ("playing", 0), ("read-only", 0), ("read-write", 0), ("required", 0),
    ("right", 0), ("root", 0), ("scope", 0), ("target", 0), ("target-within", 0), ("user-invalid", 0),
    ("user-valid", 0), ("valid", 0), ("visited", 0), ("where", -1) # https://developer.mozilla.org/en-US/docs/Web/CSS/:where
  ]
  for k in keys:
    var node = newTree(nnkExprColonExpr, newLit k[0], newLit k[1])
    add pseudoTable, node
  result =
    newStmtList(
      newLetStmt(
        ident "pseudoTable",
        newCall(
          newDotExpr(
            pseudoTable,
            ident "toCritBitTree"
          )
        )
      )
  )

definePseudoClasses()

# https://github.com/WebKit/WebKit/blob/main/Source/WebCore/css/CSSProperties.json

proc walk(p: var Parser, offset = 1) =
  var i = 0
  while offset > i:
    inc i
    p.prev = p.curr
    p.curr = p.next
    p.next = p.lex.getToken()

proc tkNot(p: var Parser, expKind: TokenKind): bool =
  result = p.curr.kind != expKind

proc tkNot(p: var Parser, expKind: set[TokenKind]): bool =
  result = p.curr.kind notin expKind

proc isProp(p: var Parser): bool =
  result = p.curr.kind == TKIdentifier

proc childOf(p: var Parser, tk: TokenTuple): bool =
  result = p.curr.pos > tk.pos and p.curr.kind != TKEOF

proc isPropOf(p: var Parser, tk: TokenTuple): bool =
  result = p.childOf(tk) and p.isProp()

proc parseComment(p: var Parser): Node =
  discard newComment(p.curr.value)
  walk p

proc parseProperty(p: var Parser): Node =
  if likely(Properties.hasKey(p.curr.value)):
    let pName = p.curr
    walk p
    if p.curr.kind == TKColon:
      walk p
      result = newProperty(pName.value)
      while p.curr.line == pName.line:
        if p.curr.kind in {TKIdentifier, TKColor, TKString, TKCenter}:
          let checkValue = Properties[pName.value].hasStrictValue(p.curr.value)
          if checkValue.exists:
            if checkValue.status in {Unimplemented, Deprecated, Obsolete, NonStandard}:
              warn("Using $ ➭ value is $", p.curr, true,
                pName.value & ": " & p.curr.value, $checkValue.status)
            result.pVal.add newString(p.curr.value)
            walk p
          else:
            walk p
            err "Invalid value $1 for $2 property" % [p.prev.value, pName.value], p.prev
        elif p.curr.kind == TKInteger:
          result.pVal.add newInt(p.curr.value)
          walk p
        elif p.curr.kind == TKFloat:
          result.pVal.add newFloat(p.curr.value)
          walk p
        elif p.curr.kind == TKVariableCall:
          let callNode = p.parseVariableCall()
          if callNode != nil:
            result.pVal.add(deepCopy(callNode))
          else:
            walk p
            return
        else:
          break # TODO error
      if p.curr.kind == TKImportant:
        result.pRule = propRuleImportant
        walk p
      elif p.curr.kind == TKDefault:
        result.pRule = propRuleDefault
        walk p
    else:
      err "Missing assignment token"
  else:
    err "Invalid CSS property", p.curr, p.curr.value

proc whileChild(p: var Parser, this: TokenTuple, parentNode: Node) =
  while p.isPropOf(this):
    let tk = p.curr
    let propNode = p.parseProperty()
    if propNode != nil:
      parentNode.props[propNode.pName] = propNode
    else: return
    if p.curr.pos == this.pos: break

  while p.childOf(this):
    let
      tk = p.curr
      node = p.parse()
    if node != nil:
      if unlikely(node.nt == NTExtend):
        # Add extended properties to parent node
        # TODO support extend, except
        if likely(parentNode.props.hasKey(node.extendIdent) == false):
          parentNode.props[node.extendIdent] = node
        else:
          error("Extending properties more than once is not allowed", p.prev, node.extendIdent)
        if p.curr.kind == TKIdentifier:
          while p.isPropOf(this):
            let tk = p.curr
            let propNode = p.parseProperty()
            if propNode != nil:
              parentNode.props[propNode.pName] = propNode
            else: return
            if p.curr.pos == this.pos: break
      else:
        node.parents = concat(@[parentNode.ident], parentNode.multiIdent)
        if not parentNode.props.hasKey(node.ident):
          parentNode.props[node.ident] = node
        else:
          for k, v in node.props.pairs():
            parentNode.props[node.ident].props[k] = v
    else: break
    if p.curr.pos == this.pos: break

proc parseSelector(p: var Parser, node: Node, tk: TokenTuple): Node =
  walk p
  var multiIdent: seq[string]
  while p.curr.kind == TKComma:
    walk p
    if p.curr.kind notin {TKColon, TKIdentifier}:
      let prefixedIdent = prefixed(p.curr)
      if prefixedIdent != node.ident and prefixedIdent notin multiIdent:
        add multiIdent, prefixed(p.curr)
        walk p
      else:
        err("Duplicated CSS declaration", p.curr, prefixedIdent)
  node.multiIdent = multiIdent
  p.whileChild tk, node
  result = node

proc parseRoot(p: var Parser): Node =
  let tk = p.curr
  result = p.parseSelector(newRoot(), tk)

proc parseClass(p: var Parser): Node =
  let tk = p.curr
  result = p.parseSelector(tk.newClass, tk)
  p.ptrNodes[tk.value] = result

proc parseID(p: var Parser): Node =
  let tk = p.curr
  result = p.parseSelector(tk.newID, tk)

proc parseTag(p: var Parser): Node =
  let tk = p.curr
  result = p.parseSelector(tk.newTag, tk)

proc parseNest(p: var Parser): Node =
  walk p
  if p.curr.kind == TKClass:
    result = p.parseClass()
    result.nested = true
  else:
    err "Invalid nest for given selector", p.curr, p.curr.value

proc parsePseudoNest(p: var Parser): Node =
  if pseudoTable.hasKey(p.next.value):
    walk p
    p.curr.col = p.prev.col
    p.curr.pos = p.prev.pos
    let tk = p.curr
    result = p.parseSelector(tk.newPseudoClass, tk)
  else:
    err "Unknown pseudo-class", p.curr, p.next.value

proc parseVariableCall(p: var Parser): Node = 
  if likely(p.memtable.hasKey(p.curr.value)):
    let valNode = p.memtable[p.curr.value]
    valNode.varValue.used = true
    result = newCall(valNode)
    walk p
  else:
    err "Undeclared variable", p.curr, "$" & p.curr.value

proc parseVariable(p: var Parser): Node =
  let tk = p.curr
  walk p # :
  if likely(p.memtable.hasKey(tk.value) == false):
    if p.next.kind in {TKIdentifier, TKColor, TKString, TKFloat, TKInteger, TKVariableCall}:
      walk p
      var varNode: Node
      if p.curr.kind != TKVariableCall:
        var varValue: string
        while p.curr.line == tk.line:
          if p.curr.kind == TKComment: break
          if p.curr.kind == TKVariableCall:
            if p.memtable.hasKey(p.curr.value):
              discard
            else:
              error("Undeclared variable", p.curr, "$" & p.curr.value)
          add varValue, p.curr.value
          add varValue, spaces(1)
          walk p
        let node = newValue(newString(varValue.strip()))
        varNode = newVariable(tk.value, node, tk)
      else:
        if p.memtable.hasKey(p.curr.value):
          varNode = deepCopy p.memtable[p.curr.value]
        else:
          error("Assigning an undeclared variable", p.curr, "$" & p.curr.value)
      p.memtable[tk.value] = varNode
      return varNode
    error("Undefined value for variable", tk, tk.value)
  else:
    if p.next.kind in {TKIdentifier, TKColor, TKString, TKFloat, TKInteger}: 
      walk p
      p.memtable[tk.value].varValue.val = newString(p.curr.value)
      result = p.memtable[tk.value]
      walk p
    elif p.next.kind == TKVariableCall:
      walk p
      let node = p.parseVariableCall()
      p.memtable[tk.value] = deepCopy node.callNode
    else:
      error("Undefined value for variable", tk, tk.value)

proc inLoop(filePath: string, lastModified: Time): Parser =
  var p = ^ spawn(partialThread(filePath, lastModified))
  var lm = lastModified
  if p.hasError:
    for row in p.error.rows:
      display(row)
    while true:
      let lastModifiedNow = filePath.getLastModificationTime()
      if p.hasError:
        if lastModifiedNow > lm:
          lm = lastModifiedNow
          p = inLoop(filePath, lm)
        sleep(220)
      else:
        return p
  else:
    result = p

proc parseImport(p: var Parser): Node = 
  if p.next.kind == TKString:
    walk p
  var filePath = addFileExt(p.curr.value, "sass").absolutePath
  var lastModified = filePath.getLastModificationTime()
  if fileExists(filePath):
    var pp = inLoop(filePath, lastModified)
    # echo pp.program.nodes.len
    result = newImport(pp.program.nodes, filePath)
    walk p
  else:
    err "Import error file not found", p.curr, p.curr.value

proc parseExtend(p: var Parser): Node =
  walk p 
  if p.curr.kind in {TKClass, TKID}:
    result = newExtend(p.curr, p.ptrNodes[p.curr.value].props)
    walk p
  else:
    error("Cannot extend", p.curr, p.curr.value)

proc getNil(p: var Parser): Node =
  result = nil
  walk p

proc parseFunctionStmt(p: var Parser): Node =
  discard

proc parseFunctionCall(p: var Parser): Node =
  discard

proc parsePreview(p: var Parser): Node =
  result = newPreview(p.curr)
  walk p

proc getPrefix(p: var Parser, kind: TokenKind): PrefixFunction =
  case p.curr.kind:
  of TKRoot:
    parseRoot
  of TKClass:
    parseClass
  of TKID:
    parseID
  of TKComment:
    parseComment
  of TKNest:
    parseNest
  of TKPseudoNest:
    parsePseudoNest
  of TKVariable:
    parseVariable
  of TKVariableCall:
    parseVariableCall
  of TKFunctionCall:
    parseFunctionCall
  of TKFunctionStmt:
    parseFunctionStmt
  of TKImport:
    parseImport
  of TKPreview:
    parsePreview
  of TKExtend:
    parseExtend
  else:
    parseTag
    # getNil

proc parse(p: var Parser): Node =
  let callFunction = p.getPrefix(p.curr.kind)
  if callFunction != nil:
    let node = p.callFunction()
    result = node

proc getProgram*(p: Parser): Program =
  result = p.program

proc getMemtable*(p: Parser): Memtable =
  result = p.memtable

template initParser(fpath: string) =
  result.lex = Lexer.init(readFile(fpath))
  result.program = Program()
  result.memtable = Memtable()
  result.curr = result.lex.getToken()
  result.next = result.lex.getToken()
  while not result.hasError:
    if result.curr.kind == TK_EOF: break
    let node = result.parse()
    if likely(node != nil):
      case node.nt
        of NTVariable:
          discard
        else:
          result.program.nodes.add(node)
  result.lex.close()
  for k, v in result.memtable.pairs():
    if unlikely(v.varValue.used == false):
      add result.warnings, ("$" & k, v.varMeta.line, v.varMeta.col)

proc partialThread(filePath: string, lastModified: Time): Parser {.thread.} =
  {.gcsafe.}:
    let lastTime = filePath.getLastModificationTime()
    result = Parser(ptype: Partial, filePath: filePath)
    filePath.initParser()

proc parseProgram*(fpath: string): Parser =
  result = Parser(ptype: Main, logger: Logger())
  result.projectDirectory = fpath.parentDir()
  fpath.initParser()

# proc parseProgram*(fpath: string): Parser =
#   var importer = resolve(fpath, fpath)
#   if not importer.hasError: 
#     result.lex = Lexer.init(importer.getFullCode)
#     result.program = Program()
#     result.memtable = Memtable()
#     result.curr = p.lex.getToken()
#     result.next = result.lex.getToken()
#     while not result.hasError:
#       if result.curr.kind == TK_EOF: break
#       let node = result.parse()
#       if likely(node != nil):
#         case node.nt
#         of NTVariable: discard
#         else: result.program.nodes.add(node)
#     result.lex.close()
#     for k, v in result.memtable.pairs():
#       if unlikely(v.varValue.used == false):
#         add result.warnings, ("$" & k, v.varMeta.line, v.varMeta.col)
#   else:
#     result.error = importer.getError()