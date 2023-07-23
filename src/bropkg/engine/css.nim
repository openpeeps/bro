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

const cssLexerSettings* =
  Settings(
    tkPrefix: "tkk",
    lexerName: "CSSLexer",
    lexerTuple: "CSSTokenTuple",
    lexerTokenKind: "CSSTokenKind",
    tkModifier: defaultTokenModifier,      
    useDefaultIdent: true,
    keepUnknown: true,
    keepChar: false,
  )

handlers:
  proc handleComment(lex: var CSSLexer, kind: CSSTokenKind) =
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

registerTokens cssLexerSettings:
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
    lex: CSSLexer
    prev, curr, next: CSSTokenTuple
    errorStack*: tuple[msg: string, line, col: int]
    hasErrors*: bool
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
  p.hasErrors = true
  p.errorStack = (msg, p.curr.line, p.curr.col)
  return # block code exec

proc parseProperties(p: var CSSParser, selector: Node) =
  while p.curr.kind notin {tkkRC, tkkEOF}:
    let pName = p.curr
    if p.next.kind == tkkColon:
      walk p, 2
    else:
      err("Missing colon")
    var values: seq[Node]
    while p.curr.kind notin {tkkSemiColon, tkkRC, tkkEOF}:
      # parse properyt values
      # todo, implement types
      values.add(newString(p.curr.value))
      walk p
    if p.curr.kind == tkkSemiColon:
      walk p
    elif p.curr.kind != tkkRC:
      err("Missing semicolon")
    selector.newProperty(pName.value, values)
  if p.curr.kind == tkkRC:
    walk p
  else:
    err("Missing closing curly bracket")

proc parseClass(p: var CSSParser): Node =
  # parse class selectors (.btn)
  result = newClass("." & p.next.value)
  walk p, 2
  if p.curr.kind == tkkLC:
    walk p
    p.parseProperties(result)

proc parseID(p: var CSSParser) =
  # parse id selectors (#myid)
  discard

proc parseTag(p: var CSSParser): Node =
  # parse named selectors and pseudo-selectors
  result = newTag(p.curr.value)
  if p.curr.kind == tkkLC:
    walk p
    p.parseProperties(result)

proc parse(p: var CSSParser): Node =
  case p.curr.kind
  of tkkDotExpr:
    # parse float numbers or class selectors 
    if p.curr.pos == 0:
      result = p.parseClass()
  of tkkHash:
    # parse id selectors
    discard
  of tkkIdentifier:
    # parse named selectors
    result = p.parseTag()
  of tkkComment: walk p # ignore
  else:
    result = nil

proc parseCSS*(input: string): tuple[status: bool, msg: string, line, col: int, stylesheet: Program] =
  var
    p = CSSParser(lex: newLexer(input))
    style = newStylesheet()
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  while p.curr.kind != tkkEOF:
    let node = p.parse()
    if node != nil:
      style.add(node)
    else: break
  p.lex.close()
  if p.lex.hasError or p.hasErrors:
    return (false, p.errorStack[0], p.errorStack[1], p.errorStack[2], nil)
  result.status = true
  result.stylesheet = style

when isMainModule:
  var style = newStylesheet()
  style.newEcho(newString("Hello, World!"))
  echo style.toCSS