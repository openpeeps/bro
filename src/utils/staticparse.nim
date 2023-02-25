import pkg/toktok
import std/[macros, json, jsonutils]

static:
  Program.settings(true, "TK_")

handlers:
  proc handleFunction(lex: var Lexer, kind: TokenKind) =
    lex.startPos = lex.getColNumber(lex.bufpos)
    setLen(lex.token, 0)
    inc lex.bufpos # <
    while true:
      case lex.buf[lex.bufpos]:
      of 'a'..'z', '0'..'9', '-':
        add lex.token, lex.buf[lex.bufpos]
        inc lex.bufpos
      else:
        break
    lex.kind = TKFn
    inc lex.bufpos # >

  proc handleOccurrences(lex: var Lexer, kind: TokenKind) =
    lex.startPos = lex.getColNumber(lex.bufpos)
    setLen(lex.token, 0)
    inc lex.bufpos # {
    var fromTo: bool
    var startWith, endWith: string
    while true:
      case lex.buf[lex.bufpos]:
      of '0'..'9':
        if fromTo:
          add endWith, lex.buf[lex.bufpos]
        else:
          add startWith, lex.buf[lex.bufpos]
        inc lex.bufpos
      of ',':
        fromTo = true
        inc lex.bufpos
      else: break
    inc lex.bufpos # }
    if endWith.len != 0:
      lex.token = startWith & "," & endWith
    else:
      lex.token = startWith
    lex.kind = TK_TIMES

tokens:
  Lsq > '['
  Rsq > ']'
  Opt > '?'
  Or  > '|'
  Repeat > '#'
  Marked > '!'
  Times  > tokenize(handleOccurrences, '{') 
  Fn  > tokenize(handleFunction, '<')
  Amp > '&':
    And ? '&'

type
  Parser* = object
    lex: Lexer
    prev, curr, next: TokenTuple

  Program* = ref object
    nodes*: seq[Node]

  NType* = enum
    ntLiteral
    ntFunction
    ntGroup
    ntGroups
    ntValue
    ntInfix

  InfixOp* = enum
    infixAnd
    infixOr

  Node* = ref object
    optional*, repeatable*, marked*: bool
    case nt*: NType
    of ntLiteral:
      strIdent*: string
    of ntFunction:
      fnIdent*: string
    of ntGroup:
      group*: seq[Node]
    of ntGroups:
      groups*: seq[Node]
    of ntInfix:
      infixOp*: InfixOp
      infixLeft*: Node
      infixRight*: Node
    of ntValue:
      value*: seq[Node]

  ParseFunction = proc(p: var Parser): Node

# fwd
proc parse(p: var Parser): ParseFunction

proc `$`*(node: Node): string =
  result = pretty(toJson(node), 2)

proc `$`*(program: Program): string =
  result = pretty(toJson(program), 2)

proc walk(p: var Parser, offset = 1) =
  var i = 0
  while offset > i:
    inc i
    p.prev = p.curr
    p.curr = p.next
    p.next = p.lex.getToken()

proc getInfixOP(tk: TokenKind): InfixOp =
  if tk == TK_OR:
    return infixOr
  result = infixAnd

proc getProcName*(strv: string): string =
  var i = 0
  while i < (strv.high + count(strv, "-")):
    case strv[i]:
    of 'a'..'z':
      add result, strv[i]
      inc i
    of '-':
      inc i
      add result, toUpperAscii(strv[i])
      inc i
    else: inc i
  return result.capitalizeAscii()

proc parseFunction(p: var Parser): Node =
  result = Node(nt: ntFunction, fnIdent: "check" & getProcName(p.curr.value))
  walk p
  if p.curr.kind == TK_OPT:
    result.optional = true
    walk p

proc parseLiteral(p: var Parser): Node =
  result = Node(nt: ntLiteral, strIdent: p.curr.value)
  walk p

proc parseInfix(p: var Parser, left: Node): Node =
  result = Node(nt: ntInfix, infixOp: getInfixOP(p.curr.kind))
  result.infixLeft = left
  walk p # && or |
  let getInfixRight = p.parse()
  result.infixRight = p.getInfixRight()

proc parseGroupNode(p: var Parser): Node =
  walk p # [
  result = Node(nt: ntGroup)
  while p.curr.kind != TK_RSQ:
    if p.curr.kind == TK_EOF: break
    let callback = p.parse()
    let subNode = p.callback()
    result.group.add(subNode)
    if p.curr.kind == TK_OR:
      walk p
  walk p # ]
  if p.curr.kind == TK_OPT:
    result.optional = true
    walk p
  if p.curr.kind == TK_REPEAT:
    result.repeatable = true
    walk p
  elif p.curr.kind == TK_MARKED:
    result.marked = true # really dont know what ! means
    walk p

proc parseGroup(p: var Parser): Node =
  var groupsNode: Node
  var groupNode = p.parseGroupNode()  
  if p.curr.kind == TK_LSQ:
    groupsNode = Node(nt: ntGroups)
    groupsNode.groups.add(groupNode)
    while p.curr.kind == TK_LSQ:
      let groupSubNode = p.parseGroupNode()
      groupsNode.groups.add(groupSubNode)

  if p.curr.kind in {TK_AND, TK_OR}:
    if groupsNode != nil:
      return p.parseInfix(groupsNode)
    return p.parseInfix(groupNode)

  if groupsNode != nil:
    return groupsNode
  result = groupNode

proc parse(p: var Parser): ParseFunction =
  case p.curr.kind
  of TK_LSQ:
    parseGroup
  of TKIdentifier:
    parseLiteral
  of TKFn:
    parseFunction
  else:
    nil

proc parseValue(p: var Parser): seq[Node] =
  # normal | <overflow-position>? [ <content-position> | left | right ]
  var
    valNode = Node(nt: ntValue)
    fn = p.parse()
    node = p.fn()
  valNode.value.add(node)
  if p.curr.kind == TK_OR:
    while p.curr.kind == TK_OR:
      walk p
      fn = p.parse()
      node = p.fn()
      if p.curr.kind == TK_OR or p.curr.kind == TK_EOF:
        valNode.value.add(node)
      else:
        result.add(valNode)
        valNode = Node(nt: ntValue)
        valNode.value.add(node)
        while p.curr.kind != TK_EOF:
          fn = p.parse()
          node = p.fn()
          valNode.value.add(node)
  result.add(valNode)
  # else:
  #   result.add(valNode)

proc parseSyntax*(syntax: string): Program =
  ## Parse regex-like sytnax and returns a collection of Nodes
  var p = Parser(lex: Lexer.init(syntax))
  result = Program()
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  while p.curr.kind != TK_EOF:
    # let parseFn = p.parse()
    # if parseFn != nil:
    #   let node = p.parseFn()
    let values = p.parseValue()
    for v in values:
      result.nodes.add(v)

# echo parseSyntax(readFile("./shit"))