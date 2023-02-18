# Bro aka NimSass
# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro

import std/[strutils, sequtils, macros, tables, critbits]
import ./tokens, ./ast, ./resolver, ./memtable

when not defined release:
  import std/[json, jsonutils] 
  
type

  Warning* = tuple[msg: string, line, col: int]

  Parser* = ref object
    lex: Lexer
    prev, curr, next: TokenTuple
    program: Program
    memtable: Memtable
    error: string
    warnings: seq[Warning]

  PrefixFunction = proc(p: Parser): Node

template err(msg: string) =
  p.error = "Error ($2:$3): $1" % [msg, $p.curr.line, $p.curr.pos]

template err(msg: string, tk: TokenTuple, sfmt: varargs[string]) =
  var errmsg = msg
  for str in sfmt:
    add errmsg, indent("\"" & str & "\"", 1)  
  p.error = "Error ($2:$3): $1" % [errmsg, $tk.line, $tk.pos]
  return

proc hasError*(p: Parser): bool =
  result = p.error.len != 0 or p.lex.hasError

proc getError*(p: Parser): string =
  result =
    if p.error.len != 0: p.error
    else: p.lex.getError

proc hasWarnings*(p: Parser): bool =
  result = p.warnings.len != 0

iterator warnings*(p: Parser): Warning =
  for w in p.warnings:
    yield w

when not defined release:
  proc `$`(node: Node): string =
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

proc walk(p: Parser, offset = 1) =
  var i = 0
  while offset > i:
    inc i
    p.prev = p.curr
    p.curr = p.next
    p.next = p.lex.getToken()

proc tkNot(p: Parser, expKind: TokenKind): bool =
  result = p.curr.kind != expKind

proc tkNot(p: Parser, expKind: set[TokenKind]): bool =
  result = p.curr.kind notin expKind

proc isProp(p: Parser): bool =
  result = p.curr.kind == TKIdentifier

proc childOf(p: Parser, tk: TokenTuple): bool =
  result = p.curr.pos > tk.pos and p.curr.kind != TKEOF

proc isPropOf(p: Parser, tk: TokenTuple): bool =
  result = p.childOf(tk) and p.isProp()

# forward definition
proc getPrefix(p: Parser, kind: TokenKind): PrefixFunction
proc parse(p: Parser): Node
proc parseCall(p: Parser): Node

proc parseComment(p: Parser): Node =
  discard newComment(p.curr.value)
  walk p

proc parseProperty(p: Parser): Node =
  let pName = p.curr
  walk p
  if p.curr.kind == TKColon:
    walk p
    result = newProperty(pName.value)
    while p.curr.line == pName.line:
      if p.curr.kind in {TKIdentifier, TKColor, TKString, TKCenter}:
        result.pVal.add newString(p.curr.value)
        walk p
      elif p.curr.kind == TKInteger:
        result.pVal.add newInt(p.curr.value)
        walk p
      elif p.curr.kind == TKFloat:
        result.pVal.add newFloat(p.curr.value)
        walk p
      elif p.curr.kind == TKVariableCall:
        let callNode = p.parseCall()
        if callNode != nil:
          result.pVal.add callNode
        else: return
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

proc whileChild(p: Parser, this: TokenTuple, parentNode: Node) =
  while p.isPropOf(this):
    let tk = p.curr
    let propNode = p.parseProperty()
    if propNode != nil:
      # if not parentNode.props.hasKey(propNode.pName):
      parentNode.props[propNode.pName] = propNode
      # else:
        # err "Duplicate property", tk, tk.value
    else: return
    if p.curr.pos == this.pos: break

  while p.childOf(this):
    let
      tk = p.curr
      node = p.parse()
    if node != nil:
      node.parents = concat(@[parentNode.ident], parentNode.multiIdent)
      if not parentNode.props.hasKey(node.ident):
        parentNode.props[node.ident] = node
      else:
        for k, v in node.props.pairs():
          # if not parentNode.props[node.ident].props.hasKey(k):
          parentNode.props[node.ident].props[k] = v
          # else:
            # err "Duplicate property", tk, k
    else: break
    if p.curr.pos == this.pos: break

proc parseSelector(p: Parser, node: Node, tk: TokenTuple): Node =
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

proc parseRoot(p: Parser): Node =
  let tk = p.curr
  result = p.parseSelector(newRoot(), tk)

proc parseClass(p: Parser): Node =
  let tk = p.curr
  result = p.parseSelector(tk.newClass, tk)

proc parseID(p: Parser): Node =
  let tk = p.curr
  result = p.parseSelector(tk.newID, tk)

proc parseTag(p: Parser): Node =
  let tk = p.curr
  result = p.parseSelector(tk.newTag, tk)

proc parseNest(p: Parser): Node =
  walk p
  if p.curr.kind == TKClass:
    result = p.parseClass()
    result.nested = true
  else:
    err "Invalid nest for given selector", p.curr, p.curr.value

proc parsePseudoNest(p: Parser): Node =
  if pseudoTable.hasKey(p.next.value):
    walk p
    p.curr.col = p.prev.col
    p.curr.pos = p.prev.pos
    let tk = p.curr
    result = p.parseSelector(tk.newPseudoClass, tk)
  else:
    err "Unknown pseudo-class", p.curr, p.next.value

proc parseVariable(p: Parser): Node =
  let tk = p.curr
  walk p # :
  if likely(p.memtable.hasKey(tk.value) == false):
    if p.next.kind in {TKIdentifier, TKColor, TKString, TKFloat, TKInteger}: 
      walk p
      var varValue: string
      while p.curr.line == tk.line:
        add varValue, p.curr.value
        add varValue, spaces(1)
        walk p
      let node = newValue(newString(varValue.strip()))
      let varDecl = newVariable(tk.value, node, tk)
      p.memtable[tk.value] = varDecl
      return varDecl
    err "Undefined value for variable", tk, tk.value
  else:
    if p.next.kind in {TKIdentifier, TKColor, TKString, TKFloat, TKInteger}: 
      walk p
      p.memtable[tk.value].varValue.val = newString(p.curr.value)
      result = p.memtable[tk.value]
      walk p
    else:
      err "Undefined value for variable", tk, tk.value

proc parseCall(p: Parser): Node = 
  if likely(p.memtable.hasKey(p.curr.value)):
    let valNode = p.memtable[p.curr.value]
    valNode.varValue.used = true
    result = newCall(valNode)
    walk p
  else:
    err "Undeclared variable", p.curr, "$" & p.curr.value

proc getNil(p: Parser): Node =
  result = nil
  walk p

proc getPrefix(p: Parser, kind: TokenKind): PrefixFunction =
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
    parseCall
  else:
    parseTag
    # getNil

proc parse(p: Parser): Node =
  let callFunction = p.getPrefix(p.curr.kind)
  if callFunction != nil:
    let node = p.callFunction()
    result = node

proc getProgram*(p: Parser): Program =
  result = p.program

proc getMemtable*(p: Parser): Memtable =
  result = p.memtable

proc parseProgram*(fpath: string): Parser =
  var importer = resolve(fpath, fpath)
  var p = Parser()
  if not importer.hasError: 
    p.lex = Lexer.init(importer.getFullCode)
    p.program = Program()
    p.memtable = Memtable()
    p.curr = p.lex.getToken()
    p.next = p.lex.getToken()
    while not p.hasError:
      if p.curr.kind == TK_EOF: break
      let node = p.parse()
      if likely(node != nil):
        case node.nt
        of NTVariable: discard
        else: p.program.nodes.add(node)
    p.lex.close()
    for k, v in p.memtable.pairs():
      if unlikely(v.varValue.used == false):
        add p.warnings, ("$" & k, v.varMeta.line, v.varMeta.col)
    result = p
  else:
    p.error = importer.getError()
    result = p