# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

# This module tokenizes and parses plain CSS code
# into a BRO-compatible abstract syntax tree (AST)
# which can then be imported into BASS files.
# Magic!

import toktok
import std/[tables]
import ./ast, ./compiler

when not defined release:
  import std/[json, jsonutils]

handlers:
  proc handleComment(lex: var Lexer, kind: TokenKind) =
    lexReady lex
    inc lex.bufpos, 2
    while true:
      if lex.current == '*' and lex.next('/'):
        lex.kind = kind
        break
      elif lex.buf[lex.bufpos] == EndOfFile:
        lex.kind = kind
        break
      else:
        add lex

registerTokens defaultSettings:
  lc = '{'
  rc = '}'
  lp = '('
  rp = ')'
  comma = ','
  colon = ':'
  semiColon = ';'
  dotExpr = '.'
  hash = '#'
  circumflex = '^'
  amp = '&'
  percent = '%'
  atRule = '@'
  rule = '!':
    ruleImportant = "important"
    ruleDefault = "default"
  minus = '-':
    varDef = '-'
  plus = '+'
  gt = '>'
  multiply = '*'
  divide = '/':
    comment = tokenize(handleComment, '*')

type
  CSSParser = object
    lex: Lexer
    prev, curr, next: TokenTuple
    errorMessage: string
    hasError: bool
    # stylesheet: Stylesheet

when not defined release:
  proc `$`(node: Node): string = pretty(node.toJson(), 2)
  proc `$`(program: Program): string = pretty(program.toJson(), 2)

proc walk(p: var CSSParser, offset = 1) =
  var i = 0
  while offset > i:
    inc i
    p.prev = p.curr
    p.curr = p.next
    p.next = p.lex.getToken()

template err(msg: string) =
  p.hasError = true
  p.errorMessage = "($1:$2) " % [$(p.curr.line), $(p.curr.col)]
  p.errorMessage.add(msg)
  return # block code exec

proc parseProperties(p: var CSSParser, selector: Node) =
  while p.curr.kind notin {tkRC, tkEOF}:
    let pName = p.curr
    if p.next.kind == tkColon:
      walk p, 2
    else:
      err("Missing colon")
    var values: seq[Node]
    while p.curr.kind notin {tkSemiColon, tkEOF}:
      # todo, implement types
      values.add(newValue(newString(p.curr.value)))
      walk p
    if p.curr.kind == tkSemiColon:
      walk p
    elif p.curr.kind != tkRC:
      err("Missing semicolon")
    selector.newProperty(pName.value, values)
  if p.curr.kind == tkRC:
    walk p
  else:
    err("Missing closing curly bracket")

proc parseClass(p: var CSSParser): Node =
  # parse class selectors (.btn)
  result = newClass(p.next.value)
  walk p, 2
  if p.curr.kind == tkLC:
    walk p
    p.parseProperties(result)

proc parseID(p: var CSSParser) =
  # parse id selectors (#myid)
  discard

proc parseTag(p: var CSSParser): Node =
  # parse named selectors and pseudo-selectors
  result = newTag(p.curr.value)
  if p.curr.kind == tkLC:
    walk p
    p.parseProperties(result)

proc parse(p: var CSSParser): Node =
  case p.curr.kind
  of tkDotExpr:
    # parse float numbers or class selectors 
    if p.curr.pos == 0:
      result = p.parseClass()
  of tkHash:
    # parse id selectors
    discard
  of tkIdentifier:
    # parse named selectors
    result = p.parseTag()
  of tkComment: walk p # ignore
  else:
    result = nil

proc parseCSS(input: string) =
  var
    p = CSSParser(lex: Lexer.init(input))
    style = newStylesheet()
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  while p.curr.kind != tkEOF:
    let node = p.parse()
    if node != nil:
      style.add(node)
    else: break
  p.lex.close()

  if p.lex.hasError:
    echo p.lex.error
    return
  elif p.hasError:
    echo p.errorMessage
    return
  echo style
  echo style.toCSS

when isMainModule:
  var style = newStylesheet()
  style.newEcho(newString("Hello, World!"))
  echo style.toCSS