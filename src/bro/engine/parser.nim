# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[strutils, tables, macros, options]
import pkg/vancode/interpreter/[errors, ast]
from pkg/openparser/css import loadCssData, getPropertySyntax, CssData

import ./lexer

var parserCssData = loadCssData()
proc isKnownCssProperty*(name: string): bool =
  getPropertySyntax(parserCssData, name) != nil

type
  Parser* = object
    lex: Lexer
    prev, curr, next: TokenTuple
    inValue*: bool # when true, identifiers are parsed as CSS values, not selectors
    inCaseBlock*: bool # when true, 'of' and 'else' terminate case branches
    inBlockBody*: bool # when true, disables indented-block selector heuristic (inside parseBlock)
    inForIterable*: bool # when true, disables colon selector heuristic (inside for iterable expr)
    arrayLits*: Table[string, Node] # var name -> nkArray literal for unrolling
  
  BroParserError* = object of ValueError
    file: string
    ln, col: int
    fatal*: bool

const
  MathOperators = {tkPlus, tkMinus, tkAsterisk, tkDivide}
  LogicalOperators = {tkAnd, tkOr, tkAndAnd, tkOrOr}
  ComparisonOperators = {tkDoubleEqual, tkNotEqual, tkGT, tkGTE, tkLT, tkLTE}
  Operators = ComparisonOperators + MathOperators + {tkAssign}
  Strings = {tkString}
  Assignables = {tkKeywordTrue, tkKeywordFalse, tkInt, tkFloat, tkIdentifier} + Strings

proc error(tk: TokenTuple, msg: string, fatal = false) =
  ## Raise a parsing error on the given node.
  ## `fatal` errors abort parsing instead of being recovered.
  raise (ref BroParserError)(
          # file: node.file,
          ln: tk.line,
          col: tk.col,
          fatal: fatal,
          msg: ErrorFmt % ["", $tk.line, $tk.col, msg])


const
  OperatorPrecedence = {
    "+": 10, "-": 10,
    "*": 20, "/": 20,
    ".": 30,
    "[": 40,
    ".": 45,
    "==": 5, "!=": 5,
    ">": 5, "<": 5, ">=": 5, "<=": 5,
    "and": 3, "&&": 3,
    "or": 2, "||": 2,
    "&": 6
  }.toTable

#
# Parser utility functions
#
proc skipNextComment(p: var Parser) =
  # Skip comments until the next token
  # This is used to skip inline comments.
  while true:
    case p.next.kind
    of tkComment:
      p.next = p.lex.getToken() # skip inline comments
    else: break

template ruleGuard(body) =
  ## Helper used by {.rule.} to update line info appropriately for nodes.
  when declared(result):
    let
      ln = p.curr.line
      col = p.curr.col
  body
  when declared(result):
    if result != nil:
      result.ln = ln
      result.col = col
      # result.file = scan.file

macro rule(pc) =
  ## Adds a ``scan`` parameter to a proc and wraps its body in a call to
  ## ``ruleGuard``.
  # pc[3].insert(1, newIdentDefs(ident"scan", newTree(nnkVarTy, ident"Scanner")))
  if pc[6].kind != nnkEmpty:
    pc[6] = newCall("ruleGuard", newStmtList(pc[6]))
  pc

type
  PrefixFunction* = proc (p: var Parser, minPrec = 0): Node

macro prefixHandle(name: untyped, body: untyped) =
  # Create a new prefix procedure with `name` and `body`
  name.newProc(
    [
      ident("Node"), # return type
      nnkIdentDefs.newTree(
        ident"p",
        nnkVarTy.newTree(
          ident"Parser"
        ),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident"minPrec",
        ident"int",
        newLit(0)
      )
    ],
    body,
    pragmas = nnkPragma.newTree(ident("rule"))
  )

proc walk(p: var Parser, offset = 1) =
  # Walk the parser state to the next token.
  # `offset` is the number of tokens to walk
  var i = 0
  while offset > i:
    inc i
    p.prev = p.curr
    p.curr = p.next
    p.next = p.lex.getToken()
    p.skipNextComment()

proc walkOpt(p: var Parser, kind: TokenKind) =
  # This is used to skip over tokens that are not needed
  # in the current context.
  if p.curr.kind == kind:
    walk(p)

proc walkOptSemiColon(p: var Parser) =
  # This is used to skip over the optional semicolon
  # at the end of a statement.
  if p.curr.kind == tkSemicolon:
    walk(p)
  elif p.curr.kind notin {tkEOF, tkRBrace} and p.curr.line == p.prev.line:
    p.curr.error("Unexpected token after statement; missing semicolon or newline?")

template expectWalk(k: TokenKind) =
  if likely(p.curr.kind == k):
    walk p
  else: return nil

template expectWalk(k: TokenKind, bdy) =
  if likely(p.curr.kind == k):
    walk p
    bdy
  else: return

proc skipComments(p: var Parser) =
  while p.curr.kind in {tkComment, tkDocBlock}:
    walk p

template caseNotNil(x: Node, body): untyped =
  if likely(x != nil):
    body
  else: return nil

template caseNotNil(x: Node, body, then): untyped =
  if likely(x != nil):
    body
  else: then

proc isChild(tk, parent: TokenTuple): bool {.inline.} =
  tk.col > parent.col and (tk.line > parent.line and tk.kind != tkEOF)

proc isInfix(p: var Parser): bool {.inline.} =
  p.curr.kind in Operators

proc isInfix(tk: TokenTuple): bool {.inline.} =
  tk.kind in Operators

proc `isnot`(tk: TokenTuple, kind: TokenKind): bool {.inline.} =
  tk.kind != kind

proc `is`(tk: TokenTuple, kind: TokenKind): bool {.inline.} =
  tk.kind == kind

proc `in`(tk: TokenTuple, kind: set[TokenKind]): bool {.inline.} =
  tk.kind in kind

proc `notin`(tk: TokenTuple, kind: set[TokenKind]): bool {.inline.} =
  tk.kind notin kind

#
# Forward declrations
#
proc parseStmt(p: var Parser, minPrec = 0): Node
proc getPrefixFn(p: var Parser, minPrec: int): PrefixFunction
proc parsePrefix(p: var Parser, minPrec = 0): Node
proc parseExpression(p: var Parser, minPrec = 0): Node
proc parseIdent(p: var Parser, minPrec = 0): Node
proc parseObjectStorage(p: var Parser, minPrec = 0): Node


#
# Infix Handlers
#
proc getPrecedence(op: string): int {.inline.} =
  case op
  of "+", "-": 10
  of "*", "/": 20
  of ".": 45
  of "[": 40
  of "==", "!=", ">", "<", ">=", "<=": 5
  of "is", "isnot": 5
  of "and", "&&": 3
  of "or", "||": 2
  of "=": 1
  of "&": 6
  else: 0

proc isInfix(kind: TokenKind, minPrec = 0): (bool, int, Option[string]) {.inline.} =
  var opStr: string
  case kind
  of tkPlus: opStr = "+"
  of tkMinus: opStr = "-"
  of tkAsterisk: opStr = "*"
  of tkDivide: opStr = "/"
  of tkGT: opStr = ">"
  of tkGTE: opStr = ">="
  of tkLT: opStr = "<"
  of tkLTE: opStr = "<="
  of tkDoubleEqual: opStr = "=="
  of tkNotEqual: opStr = "!="
  of tkAmp: opStr = "&"
  of tkAssign: opStr = "="
  of tkDot: opStr = "."
  of tkLBracket: opStr = "["
  of tkAnd: opStr = "and"
  of tkKeywordIs: opStr = "is"
  of tkKeywordIsnot: opStr = "isnot"
  of tkAndAnd: opStr = "&&"
  of tkOr: opStr = "or"
  of tkOrOr: opStr = "||"
  else: return
  let prec = getPrecedence(opStr)
  result = (prec > minPrec, prec, some(opStr))

#
# Parse handlers
#
prefixHandle parseIdent:
  # parse an identifier
  result = ast.newIdent(p.curr.value)
  walk p # tkIdentifier

prefixHandle parseCall:
  # parse a function call
  result = ast.newCall(ast.newIdent(p.curr.value))
  walk p # tkIdentifier
  # parse function arguments wrapped in parentheses
  # and mark expectRP as true to expect a closing parenthesis
  var expectRP = p.curr.kind == tkLParen
  if expectRP: walk p # tkLParen
  if p.curr isnot tkRParen:
    while true:
      # checking for the next token
      case p.curr.kind
      of tkEOF:
        if expectRP:
          p.curr.error("expected closing ')' for function call", fatal = true)
        break
      of tkRParen:
        if expectRP:
          walk p # tkRParen
        break
      of tkComma:
        walk p # skip to next argument
      else:
        if p.curr.kind == tkIdentifier and p.next.kind == tkAssign:
          # parse a named argument
          let name = ast.newIdent(p.curr.value)
          walk p # tkIdentifier
          walk p # tkAssign
          let value = p.parseExpression()
          let namedArg = ast.newTree(nkColon, name, value)
          result.add(namedArg)
        else:
          # parse a normal argument
          let arg = p.parseExpression()
          caseNotNil arg:
            result.add(arg)
        continue
  else: walk p # tkRParen

prefixHandle parseString:
  # parse a string
  result = ast.newStringLit(p.curr.value)
  walk p

prefixHandle parseNullLit:
  result = ast.newNode(nkNil)
  walk p

prefixHandle parseBoolLit:
  # parse a boolean literal
  result = ast.newBoolLit(p.curr.kind == tkKeywordTrue)
  walk p

const unitSizeSuffixes = ["px", "em", "rem", "%", "vh", "vw", "vmin", "vmax",
  "s", "ms", "deg", "rad", "grad", "turn", "dpi", "dpcm", "dppx",
  "Hz", "kHz", "fr", "ch", "ex", "cm", "mm", "in", "pt", "pc"]

prefixHandle parseNumber:
  # parse a number (int or float)
  let num = p.curr
  if p.curr.kind == tkInt:
    result =
      try:
        ast.newIntLit(parseInt(num.value))
      except ValueError:
        nil
  else:
    # assume tkFloat
    result =
      try:
        ast.newFloatLit(parseFloat(num.value))
      except ValueError:
        nil
  if result == nil: discard # todo error
  if p.next.line == num.line and p.next.wsno == 0:
    if p.next.kind == tkIdentifier:
      # handle unit suffixes for numbers, e.g., `10px`, `2em`, etc.
      walk p # consume the number token
      let suffix = p.curr.value
      if suffix in unitSizeSuffixes:
        result = ast.newNode(nkUnit).add([result, ast.newIdent(suffix)])
      walk p # consume the suffix identifier
    elif p.next.kind == tkPercent:
      walk p # consume the number token
      result = ast.newNode(nkUnit).add([result, ast.newIdent("%")])
      walk p # consume % token
    else:
      walk p # consume the number token
  else:
    walk p # consume the number token

prefixHandle parseMinus:
  # unary minus: -10px, -0.25em, -5
  walk p # tkMinus
  if p.curr.kind in {tkInt, tkFloat}:
    result = p.parseNumber()
    caseNotNil result:
      case result.kind
      of nkInt: result.intVal = -result.intVal
      of nkFloat: result.floatVal = -result.floatVal
      of nkUnit:
        if result[0].kind == nkInt:
          result[0].intVal = -result[0].intVal
        else:
          result[0].floatVal = -result[0].floatVal
      else: discard
  else:
    # fallback for other operands (e.g. `-$var`): desugar to `0 - x`
    let operand = p.parseExpression()
    caseNotNil operand:
      result = ast.newInfix(ast.newIdent("-"), ast.newIntLit(0), operand)

prefixHandle parseUnaryPlus:
  # unary plus: +5px, +.5, +10 — the sign is dropped in CSS output.
  # Only fires when `+` starts an expression (infix `a + b` is unaffected).
  if p.next.kind in {tkInt, tkFloat}:
    walk p # tkPlus
    result = p.parseNumber()
  else:
    result = nil

proc collectRawCall(p: var Parser, minPrec = 0): Node =
  ## Collect a CSS function call as raw source text preserving internal spacing
  ## verbatim: `rgb(13 110 253 / 50%)`, `linear-gradient(to right, red, blue)`.
  ## Assumes `p.curr` is the function name identifier.
  let startPos = p.curr.pos
  var depth = 0
  while p.curr.kind notin {tkEOF}:
    case p.curr.kind
    of tkLParen: inc depth
    of tkRParen:
      dec depth
      if depth <= 0:
        break
    else: discard
    walk p
  if p.curr.kind == tkRParen:
    let endPos = p.curr.pos
    walk p # tkRParen
    var raw = p.lex.input[startPos .. endPos]
    # Collapse newlines/indentation to single spaces so multi-line
    # linear-gradient(...) stays minified; keep ", " for test expectations
    raw = raw.replace("\r\n", " ").replace("\n", " ").replace("\r", " ").replace("\t", " ")
    raw = raw.splitWhitespace().join(" ")
    raw = raw.replace("( ", "(").replace(" )", ")")
    result = ast.newIdent(raw)
  else:
    p.curr.error("expected closing ')' for function call", fatal = true)

prefixHandle parsePrefix:
  let parseFn = p.getPrefixFn(minPrec)
  if parseFn != nil: 
    return parseFn(p)

proc createNullLit(p: var Parser): Node {.rule.} =
  result = ast.newNode(nkNil)
  walk p

proc createIdentNode(p: var Parser): Node {.rule.} = 
  result = ast.newIdent(p.curr.value)
  walk p # tkIdentifier

proc getVarIdent(p: var Parser, varIdent: bool): Node {.rule.} =
  # get the identifier name from the current token
  result = p.createIdentNode()
  if varIdent:
    # variable definitions can be suffixed with an asterisk
    # to mark them as exported (public)
    if p.curr is tkAsterisk:
      walk p
      result = ast.newNode(nkPostfix).add([ast.newIdent("*"), result])

proc parseIdentDefs(p: var Parser): Node {.rule.} =
  ## Parse identifier definitions
  result = newNode(nkIdentDefs)
  if p.curr.kind == tkIdentifier:
    let identNode = p.getVarIdent(true)
    var
      ty = newEmpty()
      val = newEmpty()
      vars: seq[Node]
    vars.add(identNode)
    while true:
      case p.curr.kind
      of tkColon:
        walk p # tkColon
        if p.curr is tkIdentifier:
          ty = p.parseIdent()
          # if p.curr is tkLBracket:
          #   ty = p.parseGenericType(ty)
        elif p.curr is tkKeywordVar:
          ty = ast.newNode(nkVarTy)
          if p.next is tkIdentifier:
            ty.varType = ast.newIdent(p.next.value)
            walk p, 2
      of tkAssign:
        # parse an implicit assignment
        walk p # tkAssign
        val = p.parseExpression(minPrec = 0)
        break
      of tkComma:
        # parse a comma separated list of identifiers
        if ty.kind == nkEmpty and p.next is tkIdentifier:
          walk p # tkComma
          # parse another variable separated by a comma
          vars.add(p.parseExpression())
        else: break
      else: break
    vars.add(ty)
    vars.add(val)
    result.add(vars)

proc parseVarIdent(p: var Parser): Node {.rule.} =
  # parse a variable identifier, which can be suffixed with
  #an asterisk to mark it as exported (public)
  result = ast.newNode(nkIdentDefs)
  while true:
    let identNode = p.getVarIdent(true)
    var
      ty = newEmpty()
      val = newEmpty()
    # check for a type annotation
    if p.curr.kind == tkColon:
      walk p  # Consume `:`
      if p.curr.kind == tkIdentifier:
        ty = p.parseIdent()
      else:
        p.curr.error("Expected type after ':'")
    # check for an assignment
    if p.curr.kind == tkAssign:
      walk p  # Consume `=`
      val = p.parseExpression()
    # add the identifier, type, and value to the result
    result.add(ast.newTree(nkAssign, identNode, ty, val))
    if p.curr.kind == tkComma:
      if p.next.kind == tkIdentifier and p.next.col == identNode.col:
        walk p # tkComma
      else: break
    else: break

prefixHandle parseVar:
  ## Parse a variable declaration.
  case p.curr.kind
  of tkKeywordVar:
    result = ast.newNode(nkVar)
  of tkKeywordLet:
    result = ast.newNode(nkLet)
  of tkKeywordConst:
    result = ast.newNode(nkConst)
  else:
    p.curr.error(ErrUnexpectedToken % $p.curr.kind)
  walk p
  result.add(p.parseVarIdent())
  # remember array literals for for-loop unrolling (var $a = [ ... ])
  if result.len > 0 and result[0].kind == nkIdentDefs:
    for child in result[0].children:
      if child.kind == nkAssign and child.len >= 3 and child[2].kind in {nkArray, nkObjectStorage}:
        # child[0] is the ident ($name)
        var idNode = child[0]
        # handle possible nested ident inside (e.g. $a)
        if idNode.kind == nkIdent:
          p.arrayLits[idNode.ident] = child[2]
        elif idNode.kind == nkIdentDefs and idNode.len > 0 and idNode[0].kind == nkIdent:
          p.arrayLits[idNode[0].ident] = child[2]
  p.walkOptSemiColon() # optional semicolon

prefixHandle parseReturn:
  # parse a return statement
  result = ast.newNode(nkReturn)
  walk p # tkKeywordReturn
  if p.curr.kind != tkSemicolon and p.curr.kind != tkEOF:
    let retExpr = p.parseExpression()
    caseNotNil retExpr:
      result.add(retExpr)
  p.walkOptSemiColon() # optional semicolon

prefixHandle parseBreak:
  # parse a break statement
  result = ast.newNode(nkBreak)
  walk p # tkKeywordBreak
  p.walkOptSemiColon() # optional semicolon

prefixHandle parseEcho:
  # parse an echo statement: echo expr
  # desugars to nkCall("echo", expr) so the VM's echo foreign procs handle it
  result = ast.newCall(ast.newIdent("echo"))
  walk p # tkKeywordEcho
  if p.curr.kind notin {tkSemicolon, tkEOF, tkRBrace}:
    let exprNode = p.parseExpression()
    caseNotNil exprNode:
      result.add(exprNode)
  p.walkOptSemiColon() # optional semicolon

prefixHandle parseContinue:
  # parse a continue statement
  result = ast.newNode(nkContinue)
  walk p # tkKeywordContinue
  p.walkOptSemiColon() # optional semicolon

proc parseCommaIdentList(p: var Parser, start,
      term: static TokenKind, results: var seq[Node]): bool =
  # parse a comma separated list of expressions
  walk p # start (e.g., tkLParen)
  if p.curr isnot term:
    while p.curr isnot tkEOF:
      let def: Node = p.parseIdentDefs()
      caseNotNil def:
        results.add(def)
      do: return false
      # checking for the next token
      # to determine if we have a comma separated list
      # or is the end of the list
      case p.curr.kind
      of tkComma, tkSemiColon:
        walk p # skip commas
      of term:
        walk p
        break # end of the list, break the loop
      else: return
  else: walk p # skip term, we have an empty list
  result = true

proc parseFunctionHead(p: var Parser, isAnon: bool, name, formalParams: var Node) =
  # parse the function head
  if not isAnon:
    name = ast.newIdent(p.curr.value)
    walk p
    if p.curr is tkAsterisk:
      # suffixed with an asterisk marks the function as exported (public)
      walk p # tkAsterisk
      name = ast.newNode(nkPostfix).add([ast.newIdent("*"), name])
  else:
    name = ast.newEmpty() # anonymous function
  formalParams = newTree(nkFormalParams, newEmpty())
  
  # parse function parameters
  if p.curr is tkLParen:
    var params: seq[Node]
    if p.parseCommaIdentList(tkLParen, tkRParen, params):
      formalParams.add(params)
  
  # parse return type (if any)
  if p.curr is tkColon and p.next is tkIdentifier:
    walk p # tkColon
    let returnType = p.parseIdent()
    formalParams[0] = returnType # the return type is stored in the first child

proc parseBlock(p: var Parser, indentPos = 0,
            parseFnBlock: static bool = false): Node {.rule.} =
  # parse a block of code
  var
    closingBlock: bool
    closed = false
    stmts = newSeq[Node](0)
  if p.curr is tkLBrace:
    closingBlock = true
    walk p # tkLBrace
  elif p.curr is (
      when parseFnBlock == true: tkAssign
                            else: tkColon
      ): walk p
  let savedInBlockBody = p.inBlockBody
  p.inBlockBody = true
  defer: p.inBlockBody = savedInBlockBody
  while p.curr isnot tkEOF:
    if closingBlock and p.curr is tkRBrace:
      walk p; closed = true; break # tkRBrace
    elif not closingBlock and p.curr.col <= indentPos: break
    elif p.inCaseBlock and p.curr.kind in {tkKeywordOf, tkKeywordElse}: break
    let subNode =
      if p.curr.kind == tkIdentifier and p.next.kind == tkColon and p.next.line == p.curr.line:
        let propL = p.curr.line
        let propC = p.curr.col
        let propName = ast.newIdent(p.curr.value)
        walk p, 2 # tkIdentifier > tkColon
        let propValue = p.parseValueList()
        p.walkOptSemiColon()
        let propNode = ast.newTree(nkColon, propName, propValue)
        propNode.ln = propL
        propNode.col = propC
        propNode
      else:
        p.parseExpression()
    caseNotNil subNode:
      stmts.add(subNode)
  if closingBlock and not closed:
    p.curr.error("expected closing '}' for block", fatal = true)
  result = ast.newTree(nkBlock, stmts)

proc parseValueList(p: var Parser): Node =
  ## Parse a list of expressions (e.g., 10px 20px, 13, 110, 253,
  ## or `right 0.75rem center, center right 2.25rem`).
  ## Space-separated tokens form a segment; commas separate segments.
  p.inValue = true
  defer: p.inValue = false
  var segments: seq[seq[Node]]
  var values: seq[Node]
  while true:
    # Empty value (e.g. `--x: ;` — valid custom-property reset): stop at once
    if p.curr.kind in {tkSemicolon, tkRBrace, tkEOF}:
      break
    # Handle `!important` suffix before trying to parse another value
    if p.curr.kind == tkBang and p.next.kind == tkIdentifier and p.next.value == "important":
      walk p, 2 # tkBang, tkIdentifier
      if values.len > 0:
        segments.add(values)
      let base =
        if segments.len == 1 and values.len == 1: values[0]
        elif segments.len == 1: ast.newTree(nkExprList, segments[0])
        else:
          var commaNodes: seq[Node]
          for seg in segments:
            commaNodes.add(
              if seg.len == 1: seg[0]
              else: ast.newTree(nkExprList, seg))
          ast.newTree(nkCommaList, commaNodes)
      return ast.newNode(nkPostfix).add([ast.newIdent("important"), base])
    # Comma separates segments
    if p.curr.kind == tkComma:
      if values.len > 0:
        segments.add(values)
        values = @[]
      walk p
      continue
    # Collect the next value node
    var exprNode: Node
    # Interpolation ${expr} in property values, e.g. order: ${size + 1}
    if p.curr.kind == tkIdentifier and p.curr.value == "$" and p.next.kind == tkLBrace and p.next.wsno == 0:
      walk p # $
      walk p # {
      exprNode = p.parseExpression()
      if p.curr.kind == tkRBrace:
        walk p
      # exprNode is the inside expression, will be evaluated
    # CSS function calls (rgb, var, calc, linear-gradient, url, etc.)
    # are collected as opaque raw text to preserve internal spacing
    # verbatim for modern CSS syntax like `rgb(13 110 253 / 50%)`.
    elif p.curr.kind == tkIdentifier and
        p.next.kind == tkLParen and p.next.line == p.curr.line and p.next.wsno == 0:
      exprNode = p.collectRawCall()
    elif p.curr.kind == tkKeywordVar and p.next.kind == tkLParen and p.next.line == p.curr.line:
      exprNode = p.collectRawCall()
    # In value context, true/false/null are rendered as text, not evaluated.
    # e.g. `inherits: true` → `inherits:true;`, `content: null` → `content:null;`
    elif p.inValue and p.curr.kind in {tkKeywordTrue, tkKeywordFalse, tkKeywordNull}:
      exprNode = ast.newIdent(p.curr.value)
      walk p
    else:
      exprNode = p.parseExpression()
    caseNotNil exprNode:
      values.add(exprNode)
    # Stop if next token is semicolon, block end, or newline
    case p.curr.kind
    of tkSemicolon, tkRBrace, tkEOF: break
    else: discard
    # If next token is on a new line, stop (CSS style)
    if p.curr.line != p.prev.line: break
    # Otherwise, continue parsing next value (space-separated)
  if values.len > 0:
    segments.add(values)
  if segments.len == 1 and segments[0].len == 1:
    result = segments[0][0]
  elif segments.len == 1:
    result = ast.newTree(nkExprList, segments[0])
  else:
    var commaNodes: seq[Node]
    for seg in segments:
      commaNodes.add(
        if seg.len == 1: seg[0]
        else: ast.newTree(nkExprList, seg))
    result = ast.newTree(nkCommaList, commaNodes)

proc collectAttributeSelector(p: var Parser): string =
  ## Collect a CSS attribute selector `[name=value]` as raw CSS text.
  ## Assumes `p.curr` is `tkLBracket`. Consumes through the closing `]`.
  result = "["
  walk p # tkLBracket
  while p.curr.kind notin {tkRBracket, tkEOF}:
    # preserve whitespace (e.g. `[data-x~=foo i]` — the space before the flag)
    if result.len > 1 and p.curr.wsno > 0 and result[^1] notin {'[', ' '}: # not at start or after [
      result &= " "
    case p.curr.kind
    of tkIdentifier, tkInt, tkFloat: result &= p.curr.value
    of tkString: result &= "\"" & p.curr.value & "\""
    of tkAssign: result &= "="
    of tkTildeAssign: result &= "~="
    of tkCaretAssign: result &= "^="
    of tkDollarAssign: result &= "$="
    of tkPipeAssign: result &= "|="
    of tkTilde: result &= "~"
    of tkCaret: result &= "^"
    of tkAsterisk: result &= "*"
    of tkHash: result &= "#"
    of tkColon: result &= ":"
    of tkComma: result &= ","
    of tkDot: result &= "."
    of tkPlus: result &= "+"
    of tkMinus: result &= "-"
    of tkEqual: result &= "="
    of tkKeywordTrue: result &= "true"
    of tkKeywordFalse: result &= "false"
    else: result &= $p.curr.kind
    walk p
  result &= "]"
  if p.curr.kind == tkRBracket:
    walk p

proc parseSelectorBlock(p: var Parser, indentPos = 0): Node {.rule.}

proc parseBlockSelector(p: var Parser, indentPos: int): Node {.rule.} =
  ## Collect a selector line (with commas, attributes, combinators) and its body
  var selBuf = ""
  var selList: seq[string]
  var parenDepth = 0
  var curLine = p.curr.line
  while p.curr.kind notin {tkLBrace, tkEOF} and p.curr.line == curLine:
    let txt =
      if p.curr.value.len > 0: p.curr.value
      else: $p.curr.kind
    case p.curr.kind
    of tkLParen: inc parenDepth
    of tkRParen: dec parenDepth
    else: discard
    if p.curr.kind == tkComma and parenDepth <= 0:
      selList.add(selBuf.strip())
      selBuf = ""
      walk p
      # allow wrapped selector lists: `.a,\n.b { ... }`
      if p.curr.line == curLine + 1 and p.curr.kind notin {tkLBrace, tkEOF}:
        curLine = p.curr.line
      continue
    if p.curr.kind == tkLBracket:
      selBuf &= p.collectAttributeSelector()
      continue
    # Handle ${expr} interpolation in selector names
    if p.curr.kind == tkIdentifier and p.curr.value == "$" and p.next.kind == tkLBrace and p.next.wsno == 0:
      walk p # $
      walk p # {
      var exprStr = ""
      var depth = 0
      while p.curr.kind notin {tkRBrace, tkEOF}:
        if p.curr.kind == tkLBrace: inc depth
        elif p.curr.kind == tkRBrace:
          if depth == 0: break
          dec depth
        if exprStr.len > 0 and p.curr.wsno > 0:
          exprStr &= " "
        let txt2 = if p.curr.value.len > 0: p.curr.value else: $p.curr.kind
        exprStr &= txt2
        walk p
      if p.curr.kind == tkRBrace:
        walk p
      selBuf &= "${" & exprStr.strip() & "}"
      continue
    if selBuf.len > 0 and p.curr.wsno > 0:
      selBuf &= " "
    selBuf &= txt
    walk p
  if selBuf.len > 0:
    selList.add(selBuf.strip())
  if selList.len > 0:
    let sel = ast.newNode(nkBracket)
    for s in selList:
      sel.add(ast.newIdent(s))
    let body = p.parseSelectorBlock(indentPos)
    if body != nil:
      result = ast.newTree(nkElementSelector, sel,
        ast.newEmpty(), ast.newEmpty(), body)

proc collectPseudoSuffix(p: var Parser): string =
  ## Collect a pseudo-class/element suffix: :hover, ::before, :not(caption),
  ## :is(a, b), :nth-child(2n+1). Assumes `p.curr` is `tkColon`.
  result = ":"
  walk p # first colon
  if p.curr.kind == tkColon and p.next.kind == tkIdentifier:
    result = "::"
    walk p # second colon
  if p.curr.kind in {tkIdentifier, tkKeywordNot, tkKeywordIs, tkKeywordIsnot}:
    result &= p.curr.value
    walk p # identifier
    # functional pseudo-class: :not(...), :is(...), :nth-child(...)
    if p.curr.kind == tkLParen and p.curr.line == p.prev.line:
      var depth = 0
      result &= "("
      walk p
      while p.curr.kind notin {tkEOF}:
        case p.curr.kind
        of tkLParen:
          inc depth
          result &= "("
          walk p
        of tkRParen:
          dec depth
          result &= ")"
          walk p
          if depth <= 0:
            break
        else:
          let txt =
            if p.curr.value.len > 0: p.curr.value
            else: $p.curr.kind
          if p.curr.wsno > 0:
            result &= " "
          result &= txt
          walk p

proc newCssComment(p: var Parser): Node =
  ## Wrap a doc-block token into an nkCssComment node, reconstructing its
  ## original delimiters so the stored text is fully-wrapped CSS.
  ## The lexer's buffer retains the flavor char ('!' or the second '*'),
  ## so it is stripped here before re-wrapping.
  var inner = p.curr.value
  case p.curr.kind
  of tkDocBlockBang:
    if inner.len > 0 and inner[0] == '!': inner = inner[1 ..< inner.len]
    inner = "/*!" & inner & "*/"
  of tkDocBlock:
    if inner.len > 0 and inner[0] == '*': inner = inner[1 ..< inner.len]
    inner = "/**" & inner & "*/"
  else:
    inner = ""
  result = ast.newTree(nkCssComment, ast.newStringLit(inner))
  result.ln = p.curr.line
  result.col = p.curr.col
  walk p

proc parseSelectorBlock(p: var Parser, indentPos = 0): Node {.rule.} =
  # parse a block of properties for a class selector
  var
    closingBlock: bool
    closed = false
    props = newSeq[Node](0)
  if p.curr is tkLBrace:
    closingBlock = true
    walk p # tkLBrace
  else:
    closingBlock = false
  let savedInBlockBody = p.inBlockBody
  p.inBlockBody = true
  defer: p.inBlockBody = savedInBlockBody
  while p.curr isnot tkEOF:
    # preserve doc-block banners inside rule bodies
    if p.curr.kind in {tkDocBlock, tkDocBlockBang}:
      props.add(p.newCssComment())
      continue
    p.skipComments() # skip comments between properties
    if closingBlock and p.curr is tkRBrace:
      walk p; closed = true; break # tkRBrace
    elif not closingBlock and p.curr.col <= indentPos:
      break
    # stray statement terminators between statements (e.g. `mixin();`)
    if p.curr.kind == tkSemicolon:
      walk p
      continue
    # parse property definitions, which are similar to
    # variable declarations but without the `var` keyword
    case p.curr.kind
    of tkIdentifier, tkCssVar:
      if p.next.kind == tkColon:
        var isPseudoSelector = false
        if p.curr.kind == tkIdentifier and not isKnownCssProperty(p.curr.value) and p.next.wsno == 0 and not p.curr.value.startsWith("-"):
          var probe = p
          probe.walk() # ident
          probe.walk() # colon
          if probe.curr.kind == tkColon:
            isPseudoSelector = true
          elif probe.curr.kind in {tkIdentifier, tkKeywordNot, tkKeywordIs, tkKeywordIsnot}:
            const pseudoNames = ["where","is","not","has","matches","hover","focus","active","visited","link","target","root","scope","host","slotted","first-child","last-child","nth-child","nth-of-type","nth-last-child","first-of-type","last-of-type","only-child","only-of-type","empty","enabled","disabled","checked","indeterminate","placeholder-shown","valid","invalid","required","optional","out-of-range","in-range","read-only","read-write","before","after","first-line","first-letter","selection","marker","backdrop","placeholder","file-selector-button"]
            if probe.curr.value in pseudoNames:
              isPseudoSelector = true
        if isPseudoSelector:
          let subNode = p.parseBlockSelector(p.curr.col)
          caseNotNil subNode:
            props.add(subNode)
        else:
          # parse a CSS property definition, e.g., `color: red;`
          # the semicolon is optional, so we handle it in the
          # walkOptSemiColon call after parsing the property value
          let propL = p.curr.line
          let propC = p.curr.col
          let propName = ast.newIdent(p.curr.value)
          walk p, 2 # tkIdentifier > tkColon
          # let propValue = p.parseExpression()
          let propValue = p.parseValueList()
          caseNotNil propValue:
            let propNode = ast.newTree(nkColon, propName, propValue)
            propNode.ln = propL
            propNode.col = propC
            props.add(propNode)
          p.walkOptSemiColon() # optional semicolon after each property
      elif p.next.kind in {tkIdentifier, tkComma, tkLBracket, tkDot, tkHash, tkColon, tkPlus, tkGT, tkTilde, tkAsterisk} and p.next.line == p.curr.line:
        # element selector with descendant (`ol li`), comma list (`h1, .h1`) or attribute/pseudo (`hr[role="x"]`, `a:hover`)
        let subNode = p.parseBlockSelector(p.curr.col)
        caseNotNil subNode:
          props.add(subNode)
      elif p.next.line != p.curr.line and p.next.col > p.curr.col:
        let subNode = p.parseBlockSelector(p.curr.col)
        caseNotNil subNode:
          props.add(subNode)
      else:
        let subNode = p.parseExpression()
        caseNotNil subNode:
          props.add(subNode)
    of tkDot, tkHash, tkColon, tkLBracket, tkAmp:
      let subNode = p.parseBlockSelector(p.curr.col)
      caseNotNil subNode:
        props.add(subNode)
    of tkAsterisk:
      # universal selector in nested context
      let subNode = p.parseBlockSelector(p.curr.col)
      caseNotNil subNode:
        props.add(subNode)
    of tkAt:
      # `@name(args)` — mixin include. An identifier directly attached to a
      # paren (no whitespace, same line) is an include; anything else is an
      # at-rule and is handed back to the regular at-rule parser.
      let saved = p
      let atLine = p.curr.line
      let atCol = p.curr.col
      walk p # tkAt
      var isInclude = false
      var incName = ""
      if p.curr.kind == tkIdentifier and p.curr.line == atLine:
        incName = p.curr.value
        walk p
        isInclude = p.curr.kind == tkLParen and p.curr.wsno == 0 and p.curr.line == atLine
      if isInclude:
        let callNode = ast.newCall(ast.newIdent(incName))
        callNode.ln = atLine
        callNode.col = atCol
        walk p # tkLParen
        if p.curr.kind != tkRParen:
          while true:
            case p.curr.kind
            of tkEOF:
              p.curr.error("expected closing ')' for mixin call", fatal = true)
            of tkRParen:
              walk p
              break
            of tkComma:
              walk p
            else:
              if p.curr.kind == tkIdentifier and p.next.kind == tkAssign:
                # named argument: `$name = value`
                let nm = ast.newIdent(p.curr.value)
                walk p, 2
                callNode.add(ast.newTree(nkColon, nm, p.parseExpression()))
              else:
                let arg = p.parseExpression()
                caseNotNil arg:
                  callNode.add(arg)
              continue
        else:
          walk p # tkRParen — empty argument list
        props.add(callNode)
      else:
        p = saved
        let subNode = p.parseExpression()
        caseNotNil subNode:
          props.add(subNode)
    of tkKeywordIf, tkKeywordFor, tkKeywordWhile, tkKeywordCase:
      let subNode = p.parseExpression()
      caseNotNil subNode:
        props.add(subNode)
    else:
      # we allow for nested CSS selectors and other
      # statements in the selector block, so we parse them as expressions
      let subNode = p.parseExpression()
      caseNotNil subNode:
        props.add(subNode)
  if closingBlock and not closed:
    p.curr.error("expected closing '}' for block", fatal = true)
  if not closingBlock and props.len == 0:
    # indent-style body absent: selector followed by a dedented line, EOF,
    # or garbage — never silently emit an empty rule
    p.curr.error("expected '{' or an indented block after selector", fatal = true)
  result = ast.newTree(nkBlock, props)

prefixHandle parseWhile:
  # parse a while loop
  let tokenWhile: TokenTuple = p.curr
  walk p # tkWhile
  let whileExpr: Node = p.parseExpression()
  caseNotNil whileExpr:
    let whileBlock: Node = p.parseBlock(tokenWhile.col)
    caseNotNil whileBlock:
      result = ast.newTree(nkWhile, whileExpr, whileBlock)

prefixHandle parseFunction:
  # parse a function definition
  let fnpos = p.curr.col
  walk p # tkKeywordFunction
  var name, formalParams: Node
  let isAnon = p.curr.kind != tkIdentifier
  p.parseFunctionHead(isAnon, name, formalParams)
  let fnBlock: Node = p.parseBlock(fnpos, parseFnBlock = true)
  caseNotNil fnBlock:
    result = ast.newTree(nkProc, name, ast.newEmpty(), formalParams, fnBlock)

prefixHandle parseIterator:
  # parse an iterator
  let tokenIterator = p.curr.col
  walk p # tkIterator
  var name, formalParams: Node
  parseFunctionHead(p, isAnon = false, name, formalParams)
  let fnBlock: Node = p.parseBlock(tokenIterator, parseFnBlock = true)
  caseNotNil fnBlock:
    result = ast.newTree(nkIterator, name, formalParams, fnBlock)

prefixHandle parseMixin:
  # parse a mixin definition: a reusable block of CSS declarations
  # spliced into rule bodies at call sites (Sass-style `@mixin`/`@include`)
  let mixpos = p.curr.col
  walk p # tkKeywordMixin
  if p.curr.kind != tkIdentifier:
    p.curr.error("expected mixin name after 'mixin'", fatal = true)
    return
  let name = ast.newIdent(p.curr.value)
  walk p
  var formalParams = newTree(nkFormalParams, newEmpty())
  if p.curr is tkLParen:
    var params: seq[Node]
    if p.parseCommaIdentList(tkLParen, tkRParen, params):
      formalParams.add(params)
  let body: Node = p.parseBlock(mixpos, parseFnBlock = true)
  caseNotNil body:
    result = ast.newTree(nkMixinDef, name, formalParams, body)

prefixHandle parseIf:
  # parse an if statement
  let tk = p.curr
  walk p # tkKeywordIf
  let ifExpr = p.parseExpression()
  caseNotNil ifExpr:
    if p.curr.kind notin {tkColon, tkLBrace}:
      p.curr.error("expected ':' or '{' after 'if' condition", fatal = true)
    var children = @[ifExpr]
    let ifBlock: Node = p.parseBlock(tk.col)
    caseNotNil ifBlock:
      children.add(ifBlock)
    # handle elif and else statements
    while true:
      if p.curr.kind == tkKeywordElif:
        if p.curr.col != tk.col:
          break
        walk p # tkKeywordElif
        let elifExpr = p.parseExpression()
        caseNotNil elifExpr:
          if p.curr.kind notin {tkColon, tkLBrace}:
            p.curr.error("expected ':' or '{' after 'elif' condition", fatal = true)
          let elifBlock = p.parseBlock(tk.col)
          caseNotNil elifBlock:
            children.add(@[elifExpr, elifBlock])
      elif p.curr.kind == tkKeywordElse:
        if p.curr.col != tk.col:
          break
        walk p # tkKeywordElse
        if p.curr.kind notin {tkColon, tkLBrace}:
          p.curr.error("expected ':' or '{' after 'else'", fatal = true)
        let elseBlock = p.parseBlock(tk.col)
        caseNotNil elseBlock:
          children.add(elseBlock)
      else: break
    result = ast.newTree(nkIf, children)

prefixHandle parseCase:
  let tk = p.curr
  walk p # tkKeywordCase
  let subject = p.parseExpression()
  caseNotNil subject:
    let useBrace = p.curr.kind == tkLBrace and p.curr.line == subject.ln
    if useBrace:
      walk p # tkLBrace
    elif p.curr.kind == tkColon:
      walk p # optional colon after subject
    var branches: seq[Node]
    var branchCol = -1 # column of first `of` — `else` must match
    p.inCaseBlock = true
    defer: p.inCaseBlock = false
    while p.curr.kind == tkKeywordOf:
      if not useBrace and p.curr.col > tk.col + 2:
        break
      let ofCol = p.curr.col
      if branchCol == -1: branchCol = ofCol
      walk p # tkKeywordOf
      let ofVal = p.parseExpression()
      caseNotNil ofVal:
        if p.curr.kind notin {tkColon, tkLBrace}:
          p.curr.error("expected ':' or '{' after 'of' value", fatal = true)
        let ofBlock = p.parseBlock(ofCol)
        caseNotNil ofBlock:
          branches.add(ast.newTree(nkOfBranch, ofVal, ofBlock))
    var elseBlock: Node = nil
    if p.curr.kind == tkKeywordElse:
      let elseMatch = if useBrace: true
                      elif branchCol >= 0: p.curr.col == branchCol
                      else: p.curr.col == tk.col
      if elseMatch:
        let elseCol = p.curr.col
        walk p # tkKeywordElse
        if p.curr.kind notin {tkColon, tkLBrace}:
          p.curr.error("expected ':' or '{' after 'else'", fatal = true)
        elseBlock = p.parseBlock(elseCol)
    if useBrace:
      if p.curr.kind == tkRBrace:
        walk p # tkRBrace
      else:
        p.curr.error("expected closing '}' for case block", fatal = true)
    var children = @[subject]
    for b in branches:
      children.add(b)
    if elseBlock != nil:
      children.add(elseBlock)
    result = ast.newTree(nkCase, children)

prefixHandle parseFor:
  # parse a for loop
  let tokenFor: TokenTuple = p.curr
  if tokenFor.kind == tkKeywordFor:
    walk p # tkFor
    var itemVar: Node
    if p.next is tkComma:
      itemVar = ast.newTree(nkBracket)
      itemVar.add(ast.newIdent(p.curr.value))
      walk p, 2 # tkComma
      itemVar.add(ast.newIdent(p.curr.value))
    else:
      itemVar = ast.newIdent(p.curr.value)
    walk p
    expectWalk(tkKeywordIn)
    p.inForIterable = true
    let iterExpr: Node = p.parseExpression()
    p.inForIterable = false
    caseNotNil iterExpr:
      if p.curr.kind notin {tkColon, tkLBrace}:
        p.curr.error("expected ':' or '{' after 'for' iterable", fatal = true)
      let body: Node = p.parseBlock(tokenFor.col)
      caseNotNil body:
        # Check for range-based for with interpolated selectors like .col-${size}
        # If found, unroll at parse time to generate static selectors
        var doUnroll = false
        var startVal, endVal: int
        var varName: string
        if iterExpr.kind == nkCall and iterExpr.len == 3 and iterExpr[0].kind == nkIdent and iterExpr[0].ident == "range":
          if iterExpr[1].kind == nkInt and iterExpr[2].kind == nkInt:
            startVal = iterExpr[1].intVal
            endVal = iterExpr[2].intVal
            varName = if itemVar.kind == nkIdent: itemVar.ident else: ""
            if varName.len > 0 and varName[0] == '$':
              varName = varName[1..^1]
            for child in body.children:
              if child.kind in {nkClassSelector, nkIdSelector, nkPseudoSelector, nkElementSelector}:
                let selIdent = if child[0].kind == nkIdent: child[0].ident
                               elif child[0].kind == nkBracket and child[0].len > 0 and child[0][0].kind == nkIdent: child[0][0].ident
                               else: ""
                if "${" in selIdent:
                  doUnroll = true
                  break
        if doUnroll:
          result = ast.newNode(nkBlock)
          for v in startVal..endVal:
            for child in body.children:
              var newChild = deepCopy(child)
              # Replace ${expr} in selector
              proc evalExpr(expr: string, v: int): string =
                let e = expr.strip()
                if e == varName or e == "$" & varName:
                  return $v
                elif e == varName & " + 1" or e == "$" & varName & " + 1":
                  return $(v + 1)
                elif e == varName & " - 1" or e == "$" & varName & " - 1":
                  return $(v - 1)
                elif "+" in e:
                  # simple addition like "size + 1"
                  var parts = e.split('+')
                  if parts.len == 2:
                    let a = parts[0].strip()
                    let b = parts[1].strip()
                    var av = if a == varName or a == "$" & varName: v else: 0
                    var bv = try: parseInt(b) except: 0
                    return $(av + bv)
                return e
              if newChild.kind in {nkClassSelector, nkIdSelector, nkPseudoSelector, nkElementSelector}:
                var sel = if newChild[0].kind == nkIdent: newChild[0].ident else: ""
                var isBracket = false
                if newChild[0].kind == nkBracket:
                  sel = newChild[0][0].ident
                  isBracket = true
                var outSel = ""
                var i = 0
                while i < sel.len:
                  if i+1 < sel.len and sel[i] == '$' and sel[i+1] == '{':
                    var j = sel.find('}', i+2)
                    if j != -1:
                      let expr = sel[i+2 .. j-1]
                      outSel &= evalExpr(expr, v)
                      i = j+1
                      continue
                  outSel &= sel[i]
                  inc i
                if isBracket:
                  newChild[0][0].ident = outSel
                else:
                  newChild[0].ident = outSel
                # Handle if/elif chain inside the selector's block (for _grid.bass pattern)
                if newChild.len > 3 and newChild[3].kind == nkBlock:
                  proc interpVal(n: Node, v: int, varName: string) =
                    if n.kind == nkColon and n[1] != nil and n[1].kind == nkIdent and "${" in n[1].ident:
                      var outVal = ""
                      let s = n[1].ident
                      var i = 0
                      while i < s.len:
                        if i+1 < s.len and s[i] == '$' and s[i+1] == '{':
                          var j = s.find('}', i+2)
                          if j != -1:
                            let expr = s[i+2 .. j-1]
                            outVal &= evalExpr(expr, v)
                            i = j+1
                            continue
                        outVal &= s[i]
                        inc i
                      n[1].ident = outVal
                  var newBlockChildren: seq[Node] = @[]
                  for stmt in newChild[3].children:
                    if stmt.kind == nkIf:
                      var matched = false
                      var k = 0
                      while k < stmt.len:
                        if stmt[k].kind == nkBlock:
                          # else branch
                          if not matched:
                            for c in stmt[k].children:
                              var nc = deepCopy(c)
                              interpVal(nc, v, varName)
                              newBlockChildren.add(nc)
                            matched = true
                          inc k
                        else:
                          # if/elif: cond at k, block at k+1
                          let cond = stmt[k]
                          let blk = if k+1 < stmt.len and stmt[k+1].kind == nkBlock: stmt[k+1] else: nil
                          var condTrue = false
                          if cond.kind == nkInfix and cond[0].kind == nkIdent and cond[0].ident == "==":
                            let left = cond[1]
                            let right = cond[2]
                            var leftVal = 0
                            if left.kind == nkIdent and (left.ident == varName or left.ident == "$" & varName):
                              leftVal = v
                            elif left.kind == nkInt:
                              leftVal = left.intVal
                            var rightVal = 0
                            if right.kind == nkInt:
                              rightVal = right.intVal
                            condTrue = leftVal == rightVal
                          if condTrue and not matched and blk != nil:
                            for c in blk.children:
                              var nc = deepCopy(c)
                              interpVal(nc, v, varName)
                              newBlockChildren.add(nc)
                            matched = true
                          inc k
                          if blk != nil: inc k
                    elif stmt.kind == nkCase:
                      # case/of: stmt[0]=subject, stmt[1..]=nkOfBranch, last may be else block
                      let subject = stmt[0]
                      var subjectVal = 0
                      if subject.kind == nkIdent and (subject.ident == varName or subject.ident == "$" & varName):
                        subjectVal = v
                      var matched = false
                      for bi in 1 ..< stmt.len:
                        let branch = stmt[bi]
                        if branch.kind == nkBlock:
                          # else branch
                          if not matched:
                            for c in branch.children:
                              var nc = deepCopy(c)
                              interpVal(nc, v, varName)
                              newBlockChildren.add(nc)
                            matched = true
                        elif branch.kind == nkOfBranch:
                          let ofVal = branch[0]
                          let ofBlock = branch[1]
                          var branchMatch = false
                          if ofVal.kind == nkInt:
                            branchMatch = subjectVal == ofVal.intVal
                          elif ofVal.kind == nkIdent and (ofVal.ident == varName or ofVal.ident == "$" & varName):
                            branchMatch = subjectVal == v
                          if branchMatch and not matched:
                            for c in ofBlock.children:
                              var nc = deepCopy(c)
                              interpVal(nc, v, varName)
                              newBlockChildren.add(nc)
                            matched = true
                    else:
                      # Handle ${} in property values like order: ${size + 1}
                      if stmt.kind == nkColon and stmt[1] != nil:
                        if stmt[1].kind == nkIdent and (stmt[1].ident == varName or stmt[1].ident == "$" & varName):
                          stmt[1] = ast.newIntLit(v)
                        elif stmt[1].kind == nkInfix:
                          let left = if stmt[1][1].kind == nkIdent: stmt[1][1].ident else: ""
                          let right = if stmt[1][2].kind == nkInt: $stmt[1][2].intVal else: ""
                          if (left == varName or left == "$" & varName) and right != "":
                            try:
                              let rv = parseInt(right)
                              if stmt[1][0].ident == "+":
                                stmt[1] = ast.newIntLit(v + rv)
                              elif stmt[1][0].ident == "-":
                                stmt[1] = ast.newIntLit(v - rv)
                            except: discard
                        elif stmt[1].kind == nkIdent and "${" in stmt[1].ident:
                          var outVal = ""
                          let s = stmt[1].ident
                          var i = 0
                          while i < s.len:
                            if i+1 < s.len and s[i] == '$' and s[i+1] == '{':
                              var j = s.find('}', i+2)
                              if j != -1:
                                let expr = s[i+2 .. j-1]
                                outVal &= evalExpr(expr, v)
                                i = j+1
                                continue
                            outVal &= s[i]
                            inc i
                          stmt[1].ident = outVal
                      newBlockChildren.add(stmt)
                  newChild[3] = ast.newTree(nkBlock, newBlockChildren)
              result.add(newChild)
        elif (iterExpr.kind == nkArray) or (iterExpr.kind == nkIdent and p.arrayLits.hasKey(iterExpr.ident)):
          # array-of-objects unroll (e.g. for $s in [{k:0,v:0}, {k:1,v:0.25rem}] or for $s in $spacings)
          var arrNode: Node
          if iterExpr.kind == nkArray:
            arrNode = iterExpr
          else:
            arrNode = p.arrayLits[iterExpr.ident]
          var arrVar = if itemVar.kind == nkIdent: itemVar.ident else: ""
          if arrVar.len > 0 and arrVar[0] == '$':
            arrVar = arrVar[1..^1]
          var doArrUnroll = false
          for child in body.children:
            if child.kind in {nkClassSelector, nkIdSelector, nkPseudoSelector, nkElementSelector}:
              let selIdent = if child[0].kind == nkIdent: child[0].ident
                             elif child[0].kind == nkBracket and child[0].len > 0 and child[0][0].kind == nkIdent: child[0][0].ident
                             else: ""
              if "${" in selIdent:
                doArrUnroll = true
                break
          if doArrUnroll and arrNode != nil and arrNode.len > 0:
            result = ast.newNode(nkBlock)
            proc nodeStr(n: Node): string =
              case n.kind
              of nkInt: $n.intVal
              of nkFloat:
                var s = $n.floatVal
                if s.endsWith(".0"): s.setLen(s.len - 2)
                s
              of nkString: n.stringVal
              of nkUnit:
                var b: string
                if n[0].kind == nkInt:
                  b = $(n[0].intVal)
                else:
                  b = $(n[0].floatVal)
                  if b.endsWith(".0"): b.setLen(b.len - 2)
                b & n[1].ident
              of nkIdent: n.ident
              else: ""
            proc fieldStr(obj: Node, field: string): string =
              if obj.kind == nkObjectStorage:
                for f in obj.children:
                  if f.kind == nkColon and f[0].kind == nkIdent and f[0].ident == field:
                    return nodeStr(f[1])
                  if f.kind == nkColon and f[0].kind == nkString and f[0].stringVal == field:
                    return nodeStr(f[1])
              return ""
            for elem in arrNode.children:
              for child in body.children:
                var newChild = deepCopy(child)
                proc evalArrExpr(expr: string, curElem: Node): string =
                  var e = expr.strip()
                  if e.startsWith("$"): e = e[1..^1]
                  if "." in e:
                    var parts = e.split('.', maxsplit=1)
                    let base = parts[0].strip()
                    let field = parts[1].strip()
                    if base == arrVar:
                      if curElem.kind == nkObjectStorage:
                        return fieldStr(curElem, field)
                      else:
                        return nodeStr(curElem)
                  else:
                    if e == arrVar:
                      if curElem.kind == nkObjectStorage:
                        return nodeStr(curElem)
                      return nodeStr(curElem)
                  return e
                if newChild.kind in {nkClassSelector, nkIdSelector, nkPseudoSelector, nkElementSelector}:
                  var sel = if newChild[0].kind == nkIdent: newChild[0].ident else: ""
                  var isBracket = false
                  if newChild[0].kind == nkBracket:
                    sel = newChild[0][0].ident
                    isBracket = true
                  var outSel = ""
                  var i = 0
                  while i < sel.len:
                    if i+1 < sel.len and sel[i] == '$' and sel[i+1] == '{':
                      var j = sel.find('}', i+2)
                      if j != -1:
                        let expr = sel[i+2 .. j-1]
                        outSel &= evalArrExpr(expr, elem)
                        i = j+1
                        continue
                    outSel &= sel[i]
                    inc i
                  if isBracket:
                    newChild[0][0].ident = outSel
                  else:
                    newChild[0].ident = outSel
                  if newChild.len > 3 and newChild[3].kind == nkBlock:
                    var newBlockChildren: seq[Node] = @[]
                    for stmt in newChild[3].children:
                      var nc = deepCopy(stmt)
                      if nc.kind == nkColon and nc[1] != nil:
                        # unwrap !important postfix if present
                        var valNode = nc[1]
                        var isPostfix = valNode.kind == nkPostfix
                        var inner = if isPostfix and valNode.len >= 2: valNode[1] else: valNode
                        if inner.kind == nkDot:
                          let base = inner[0]
                          let field = inner[1]
                          var baseName = ""
                          if base.kind == nkIdent: baseName = base.ident
                          if baseName.startsWith("$"): baseName = baseName[1..^1]
                          var fieldName = ""
                          if field.kind == nkIdent: fieldName = field.ident
                          if baseName == arrVar and elem.kind == nkObjectStorage:
                            for f in elem.children:
                              if f.kind == nkColon and f[0].kind == nkIdent and f[0].ident == fieldName:
                                let newVal = deepCopy(f[1])
                                if isPostfix:
                                  valNode[1] = newVal
                                  nc[1] = valNode
                                else:
                                  nc[1] = newVal
                                break
                              if f.kind == nkColon and f[0].kind == nkString and f[0].stringVal == fieldName:
                                let newVal = deepCopy(f[1])
                                if isPostfix:
                                  valNode[1] = newVal
                                  nc[1] = valNode
                                else:
                                  nc[1] = newVal
                                break
                        elif inner.kind == nkIdent:
                          var id = inner.ident
                          var stripped = if id.startsWith("$"): id[1..^1] else: id
                          if stripped == arrVar:
                            var newVal: Node
                            if elem.kind != nkObjectStorage:
                              newVal = deepCopy(elem)
                            else:
                              for f in elem.children:
                                if f.kind == nkColon and f[0].kind == nkIdent and f[0].ident == "v":
                                  newVal = deepCopy(f[1]); break
                            if newVal != nil:
                              if isPostfix:
                                valNode[1] = newVal
                                nc[1] = valNode
                              else:
                                nc[1] = newVal
                        elif inner.kind == nkIdent and "${" in inner.ident:
                          var outV = ""
                          let s = inner.ident
                          var ii = 0
                          while ii < s.len:
                            if ii+1 < s.len and s[ii] == '$' and s[ii+1] == '{':
                              var jj = s.find('}', ii+2)
                              if jj != -1:
                                let expr = s[ii+2 .. jj-1]
                                outV &= evalArrExpr(expr, elem)
                                ii = jj+1
                                continue
                            outV &= s[ii]
                            inc ii
                          if isPostfix:
                            valNode[1].ident = outV
                            nc[1] = valNode
                          else:
                            inner.ident = outV
                            nc[1] = inner
                      newBlockChildren.add(nc)
                    newChild[3] = ast.newTree(nkBlock, newBlockChildren)
                result.add(newChild)
          else:
            result = ast.newTree(nkFor, itemVar, iterExpr, body)
        else:
          result = ast.newTree(nkFor, itemVar, iterExpr, body)

prefixHandle parseClassSelector:
  # parse a class selector, which is a dot followed by an identifier
  let pos = p.curr.col
  walk p # tkDot
  if p.curr.kind == tkIdentifier:
    var selName = p.curr.value
    walk p # tkIdentifier
    while true:
      if p.curr.kind == tkColon and p.curr.line == p.prev.line and p.curr.wsno == 0:
        selName &= p.collectPseudoSuffix()
      elif p.curr.kind == tkLBracket and p.curr.line == p.prev.line:
        selName &= p.collectAttributeSelector()
      elif p.curr.kind == tkIdentifier and p.curr.value == "$" and p.next.kind == tkLBrace and p.next.wsno == 0:
        walk p # $
        walk p # {
        var exprStr = ""
        var depth = 0
        while p.curr.kind notin {tkRBrace, tkEOF}:
          if p.curr.kind == tkLBrace:
            inc depth
          elif p.curr.kind == tkRBrace:
            if depth == 0:
              break
            dec depth
          if exprStr.len > 0 and p.curr.wsno > 0:
            exprStr &= " "
          let txt = if p.curr.value.len > 0: p.curr.value else: $p.curr.kind
          exprStr &= txt
          walk p
        if p.curr.kind == tkRBrace:
          walk p
        selName &= "${" & exprStr.strip() & "}"
      else: break
    # Collect comma-separated selectors: `.a, .b, .c`
    # A selector may also start on the line after a trailing comma
    var selList: seq[string]
    while p.curr.kind == tkComma and p.curr.line == p.prev.line:
      let cline = p.curr.line
      walk p # tkComma
      var extra = ""
      if p.curr.kind == tkDot and p.curr.line in {cline, cline + 1}:
        walk p # tkDot
        if p.curr.kind == tkIdentifier:
          extra = "." & p.curr.value
          walk p
          while true:
            if p.curr.kind == tkColon and p.curr.line == p.prev.line and p.curr.wsno == 0:
              extra &= p.collectPseudoSuffix()
            elif p.curr.kind == tkLBracket and p.curr.line == p.prev.line:
              extra &= p.collectAttributeSelector()
            elif p.curr.kind == tkIdentifier and p.curr.value == "$" and p.next.kind == tkLBrace and p.next.wsno == 0:
              walk p
              walk p
              var exprStr = ""
              var depth = 0
              while p.curr.kind notin {tkRBrace, tkEOF}:
                if p.curr.kind == tkLBrace:
                  inc depth
                elif p.curr.kind == tkRBrace:
                  if depth == 0:
                    break
                  dec depth
                if exprStr.len > 0 and p.curr.wsno > 0:
                  exprStr &= " "
                let txt = if p.curr.value.len > 0: p.curr.value else: $p.curr.kind
                exprStr &= txt
                walk p
              if p.curr.kind == tkRBrace:
                walk p
              extra &= "${" & exprStr.strip() & "}"
            else: break
      elif p.curr.kind == tkHash and p.curr.line in {cline, cline + 1}:
        walk p # tkHash
        if p.curr.kind == tkIdentifier:
          extra = "#" & p.curr.value
          walk p
          while true:
            if p.curr.kind == tkColon and p.curr.line == p.prev.line and p.curr.wsno == 0:
              extra &= p.collectPseudoSuffix()
            elif p.curr.kind == tkLBracket and p.curr.line == p.prev.line:
              extra &= p.collectAttributeSelector()
            elif p.curr.kind == tkIdentifier and p.curr.value == "$" and p.next.kind == tkLBrace and p.next.wsno == 0:
              walk p
              walk p
              var exprStr = ""
              var depth = 0
              while p.curr.kind notin {tkRBrace, tkEOF}:
                if p.curr.kind == tkLBrace:
                  inc depth
                elif p.curr.kind == tkRBrace:
                  if depth == 0:
                    break
                  dec depth
                if exprStr.len > 0 and p.curr.wsno > 0:
                  exprStr &= " "
                let txt = if p.curr.value.len > 0: p.curr.value else: $p.curr.kind
                exprStr &= txt
                walk p
              if p.curr.kind == tkRBrace:
                walk p
              extra &= "${" & exprStr.strip() & "}"
            else: break
      elif p.curr.kind == tkIdentifier and p.curr.line in {cline, cline + 1}:
        extra = p.curr.value
        walk p
        while true:
          if p.curr.kind == tkColon and p.curr.line == p.prev.line and p.curr.wsno == 0:
            extra &= p.collectPseudoSuffix()
          elif p.curr.kind == tkLBracket and p.curr.line == p.prev.line:
            extra &= p.collectAttributeSelector()
          elif p.curr.kind == tkIdentifier and p.curr.value == "$" and p.next.kind == tkLBrace and p.next.wsno == 0:
            walk p
            walk p
            var exprStr = ""
            var depth = 0
            while p.curr.kind notin {tkRBrace, tkEOF}:
              if p.curr.kind == tkLBrace:
                inc depth
              elif p.curr.kind == tkRBrace:
                if depth == 0:
                  break
                dec depth
              if exprStr.len > 0 and p.curr.wsno > 0:
                exprStr &= " "
              let txt = if p.curr.value.len > 0: p.curr.value else: $p.curr.kind
              exprStr &= txt
              walk p
            if p.curr.kind == tkRBrace:
              walk p
            extra &= "${" & exprStr.strip() & "}"
          else: break
      # absorb compound/combinator tail on the extra's own line
      # (e.g. `.btn-group-lg > .btn` or `.b[size]:not(x)` as list entries)
      var tailDepth = 0
      while p.curr.kind notin {tkLBrace, tkEOF} and
            p.curr.line == p.prev.line:
        case p.curr.kind
        of tkLParen: inc tailDepth
        of tkRParen: dec tailDepth
        else: discard
        if p.curr.kind == tkComma and tailDepth <= 0:
          break # next list entry — handled by the outer loop
        if p.curr.kind notin {tkIdentifier, tkDot, tkHash, tkColon, tkLBracket, tkPlus, tkGT, tkTilde, tkAsterisk, tkLParen, tkRParen}:
          break
        if p.curr.kind == tkLBracket:
          extra &= p.collectAttributeSelector()
          continue
        let txt =
          if p.curr.value.len > 0: p.curr.value
          else: $p.curr.kind
        if extra.len > 0 and p.curr.wsno > 0:
          extra &= " "
        extra &= txt
        walk p
      if extra.len > 0:
        selList.add(extra)
    if selList.len > 0:
      # Comma-separated — build nkBracket with all selectors
      let sel = ast.newNode(nkBracket)
      sel.add(ast.newIdent("." & selName))
      for s in selList:
        sel.add(ast.newIdent(s))
      let propsBlock: Node = p.parseSelectorBlock(pos)
      caseNotNil propsBlock:
        result = ast.newTree(nkElementSelector, sel,
          ast.newEmpty(), ast.newEmpty(), propsBlock)
    elif p.curr.kind in {tkPlus, tkGT, tkTilde} or
         (p.curr.kind == tkDot and p.curr.wsno == 0 and p.curr.line == p.prev.line) or
         (p.curr.line == p.prev.line and p.curr.wsno > 0 and p.curr.kind in {tkIdentifier, tkDot, tkHash, tkLBracket, tkColon, tkAsterisk}):
      # Compound/combinator — collect as raw text, splitting wrapped
      # comma lists (`.form-floating > .form-control,\n.form-floating > …`)
      var rawSel = "." & selName
      var selLn = p.curr.line
      var parts: seq[string]
      var partDepth = 0
      while p.curr.kind notin {tkLBrace, tkEOF} and p.curr.line == selLn:
        case p.curr.kind
        of tkLParen: inc partDepth
        of tkRParen: dec partDepth
        else: discard
        if p.curr.kind == tkLBracket:
          rawSel &= p.collectAttributeSelector()
          continue
        if p.curr.kind == tkComma and partDepth <= 0:
          parts.add(rawSel.strip())
          rawSel = ""
          walk p
          # allow the next selector to start on the following line
          if p.curr.line == selLn + 1 and p.curr.kind notin {tkLBrace, tkEOF}:
            inc selLn
          continue
        let txt =
          if p.curr.value.len > 0: p.curr.value
          else: $p.curr.kind
        if rawSel.len > 0 and p.curr.wsno > 0:
          rawSel &= " "
        rawSel &= txt
        walk p
      if rawSel.strip().len > 0:
        parts.add(rawSel.strip())
      let sel = ast.newNode(nkBracket)
      for part in parts:
        sel.add(ast.newIdent(part))
      let propsBlock: Node = p.parseSelectorBlock(pos)
      caseNotNil propsBlock:
        result = ast.newTree(nkElementSelector, sel,
          ast.newEmpty(), ast.newEmpty(), propsBlock)
    else:
      # Single class selector — use nkClassSelector for AST compatibility
      let selector = ast.newIdent(selName)
      let propsBlock: Node = p.parseSelectorBlock(pos)
      caseNotNil propsBlock:
        result = ast.newTree(nkClassSelector, selector,
          ast.newEmpty(), ast.newEmpty(), propsBlock)
  
prefixHandle parseIdSelector:
  # parse an ID selector, which is a hash followed by an identifier
  let pos = p.curr.col
  walk p # tkHash
  if p.curr.kind == tkIdentifier:
    var selName = p.curr.value
    walk p # tkIdentifier
    # handle attribute selectors like [data-x] appended to id
    while p.curr.kind == tkLBracket and p.curr.line == p.prev.line:
      selName &= p.collectAttributeSelector()
    # Compound selectors (.foo.bar), combinators, or descendants collect as raw text
    if p.curr.kind in {tkPlus, tkGT, tkTilde} or
       (p.curr.kind == tkDot and p.curr.wsno == 0) or
       (p.curr.line == p.prev.line and p.curr.wsno > 0 and p.curr.kind in {tkIdentifier, tkDot, tkHash, tkLBracket, tkColon, tkAsterisk}):
      var rawSel = "#" & selName
      while p.curr.kind notin {tkLBrace, tkEOF}:
        if p.curr.kind == tkLBracket:
          rawSel &= p.collectAttributeSelector()
          continue
        let txt =
          if p.curr.value.len > 0: p.curr.value
          else: $p.curr.kind
        if rawSel.len > 0 and p.curr.wsno > 0:
          rawSel &= " "
        rawSel &= txt
        walk p
      let sel = ast.newNode(nkBracket).add(ast.newIdent(rawSel.strip()))
      let propsBlock: Node = p.parseSelectorBlock(pos)
      caseNotNil propsBlock:
        result = ast.newTree(nkElementSelector, sel,
          ast.newEmpty(), ast.newEmpty(), propsBlock)
    else:
      let selector = ast.newIdent(selName)
      let propsBlock: Node = p.parseSelectorBlock(pos)
      caseNotNil propsBlock:
        result = ast.newTree(nkIdSelector, selector,
                      ast.newEmpty(), ast.newEmpty(), propsBlock)

prefixHandle parsePseudoSelector:
  # parse a pseudo selector like `:root`, `:focus-visible`, `::before`,
  # or vendor pseudo-elements like `::-moz-focus-inner`
  let pos = p.curr.col
  walk p # tkColon
  var dcolon = false
  if p.curr.kind == tkColon:
    dcolon = true
    walk p # second colon of pseudo-element syntax
  if p.curr.kind in {tkIdentifier, tkKeywordNot, tkKeywordIs, tkKeywordIsnot}:
    var selName = p.curr.value
    walk p # tkIdentifier
    # handle attribute selectors like [data-x] appended to pseudo
    while p.curr.kind == tkLBracket and p.curr.line == p.prev.line:
      selName &= p.collectAttributeSelector()
    # Collect comma-separated selectors: `:root, [data-x], .cls`
    # A selector may also start on the line after a trailing comma
    var selList: seq[string]
    while p.curr.kind == tkComma and p.curr.line == p.prev.line:
      let cline = p.curr.line
      walk p # tkComma
      var extra = ""
      if p.curr.kind == tkDot and p.curr.line in {cline, cline + 1}:
        walk p # tkDot
        if p.curr.kind == tkIdentifier:
          extra = "." & p.curr.value
          walk p
          while p.curr.kind == tkColon and p.curr.line == p.prev.line and p.curr.wsno == 0:
            extra &= p.collectPseudoSuffix()
          while p.curr.kind == tkLBracket and p.curr.line == p.prev.line:
            extra &= p.collectAttributeSelector()
      elif p.curr.kind == tkHash and p.curr.line in {cline, cline + 1}:
        walk p # tkHash
        if p.curr.kind == tkIdentifier:
          extra = "#" & p.curr.value
          walk p
      elif p.curr.kind == tkColon and p.curr.wsno == 0 and p.curr.line in {cline, cline + 1}:
        extra = p.collectPseudoSuffix()
        while p.curr.kind == tkLBracket and p.curr.line == p.prev.line:
          extra &= p.collectAttributeSelector()
      elif p.curr.kind == tkLBracket and p.curr.line in {cline, cline + 1}:
        extra = p.collectAttributeSelector()
      elif p.curr.kind == tkIdentifier and p.curr.line in {cline, cline + 1}:
        extra = p.curr.value
        walk p
      # absorb compound/combinator tail on the extra's own line
      # (e.g. `.btn-group-lg > .btn` as an entry of a comma list)
      while p.curr.kind notin {tkLBrace, tkComma, tkEOF} and
            p.curr.line == p.prev.line and
            p.curr.kind in {tkIdentifier, tkDot, tkHash, tkColon, tkLBracket, tkPlus, tkGT, tkTilde, tkAsterisk}:
        if p.curr.kind == tkLBracket:
          extra &= p.collectAttributeSelector()
          continue
        let txt =
          if p.curr.value.len > 0: p.curr.value
          else: $p.curr.kind
        if extra.len > 0 and p.curr.wsno > 0:
          extra &= " "
        extra &= txt
        walk p
      if extra.len > 0:
        selList.add(extra)
    let sigil = if dcolon: "::" else: ":"
    if selList.len > 0:
      # Comma-separated — build nkBracket with all selectors
      let sel = ast.newNode(nkBracket)
      sel.add(ast.newIdent(sigil & selName))
      for s in selList:
        sel.add(ast.newIdent(s))
      let propsBlock: Node = p.parseSelectorBlock(pos)
      caseNotNil propsBlock:
        result = ast.newTree(nkElementSelector, sel,
          ast.newEmpty(), ast.newEmpty(), propsBlock)
    elif p.curr.kind in {tkPlus, tkGT, tkTilde} or
       (p.curr.kind == tkDot and p.curr.wsno == 0) or
       (p.curr.line == p.prev.line and p.curr.wsno > 0 and p.curr.kind in {tkIdentifier, tkDot, tkHash, tkLBracket, tkColon, tkAsterisk}):
      var rawSel = sigil & selName
      while p.curr.kind notin {tkLBrace, tkEOF}:
        if p.curr.kind == tkLBracket:
          rawSel &= p.collectAttributeSelector()
          continue
        let txt =
          if p.curr.value.len > 0: p.curr.value
          else: $p.curr.kind
        if rawSel.len > 0 and p.curr.wsno > 0:
          rawSel &= " "
        rawSel &= txt
        walk p
      let sel = ast.newNode(nkBracket).add(ast.newIdent(rawSel.strip()))
      let propsBlock: Node = p.parseSelectorBlock(pos)
      caseNotNil propsBlock:
        result = ast.newTree(nkElementSelector, sel,
          ast.newEmpty(), ast.newEmpty(), propsBlock)
    elif dcolon:
      # plain pseudo-element (`::before`) — emit via element path so the
      # double colon survives (nkPseudoSelector only adds a single colon)
      let sel = ast.newNode(nkBracket).add(ast.newIdent(sigil & selName))
      let propsBlock: Node = p.parseSelectorBlock(pos)
      caseNotNil propsBlock:
        result = ast.newTree(nkElementSelector, sel,
          ast.newEmpty(), ast.newEmpty(), propsBlock)
    else:
      let selector = ast.newIdent(selName)
      let propsBlock: Node = p.parseSelectorBlock(pos)
      caseNotNil propsBlock:
        result = ast.newTree(nkPseudoSelector, selector,
                    ast.newEmpty(), ast.newEmpty(), propsBlock)

proc parseAtRulePrelude(p: var Parser, atLine: int): string =
  var prelude = ""
  while p.curr.kind notin {tkLBrace, tkSemicolon, tkEOF} and p.curr.line == atLine:
    let txt =
      if p.curr.kind == tkString:
        "\"" & p.curr.value & "\""  # preserve quotes in at-rule preludes
      elif p.curr.value.len > 0: p.curr.value
      else: $p.curr.kind
    if prelude.len > 0 and p.curr.wsno > 0:
      prelude &= " "
    prelude &= txt
    walk p
  result = prelude.strip()

proc parseKeyframeBlock(p: var Parser, indentPos = 0): Node {.rule.} =
  var
    closingBlock: bool
    closed = false
    stmts = newSeq[Node](0)
  if p.curr.kind == tkLBrace:
    closingBlock = true
    walk p
  else:
    closingBlock = false
  while p.curr.kind notin {tkEOF}:
    p.skipComments()
    if closingBlock and p.curr.kind == tkRBrace:
      walk p; closed = true; break
    elif not closingBlock and p.curr.col <= indentPos:
      break
    var selectorName = ""
    let selCol = p.curr.col
    var selectorNames: seq[string]
    # collect comma-separated keyframe selectors: `20%, 30%`
    while true:
      case p.curr.kind
      of tkIdentifier:
        if p.curr.value in ["from", "to"]:
          selectorNames.add(p.curr.value)
          walk p
        else: break
      of tkInt, tkFloat:
        var name = p.curr.value
        walk p
        if p.curr.kind == tkPercent:
          name &= "%"
          walk p
        selectorNames.add(name)
      else: break
      if selectorNames.len == 0: break
      if p.curr.kind == tkComma and p.curr.line == p.prev.line:
        walk p # tkComma — parse next selector
      else: break
    if selectorNames.len == 0: break
    let selBlock = p.parseSelectorBlock(selCol)
    caseNotNil selBlock:
      let sel = ast.newNode(nkBracket)
      for sname in selectorNames:
        sel.add(ast.newIdent(sname))
      let keyframeNode = ast.newTree(nkElementSelector, sel,
        ast.newEmpty(), ast.newEmpty(), selBlock)
      stmts.add(keyframeNode)
  if closingBlock and not closed:
    p.curr.error("expected closing '}' for block", fatal = true)
  result = ast.newTree(nkBlock, stmts)

prefixHandle parseAtRule:
  let pos = p.curr.col
  let atLine = p.curr.line
  walk p # tkAt
  let atName =
    if p.curr.kind == tkIdentifier: p.curr.value
    elif p.curr.kind == tkKeywordImport: "import"
    else:
      p.curr.error("Expected at-rule name after @")
      return
  walk p
  var prelude = p.parseAtRulePrelude(atLine)
  let nameNode = ast.newIdent(atName)
  let preludeNode = ast.newStringLit(prelude)
  if p.curr.kind == tkLBrace or (p.curr.line != atLine and p.curr.col > pos):
    let body: Node =
      if atName == "keyframes":
        p.parseKeyframeBlock(pos)
      else:
        p.parseSelectorBlock(pos)
    caseNotNil body:
      result = ast.newTree(nkAtRule, nameNode, preludeNode, body)
  else:
    if p.curr.kind == tkSemicolon:
      walk p
    result = ast.newTree(nkAtRule, nameNode, preludeNode, ast.newTree(nkBlock))

prefixHandle parseSelector:
  # collect raw selector text until we hit the selector block `{`
  var selBuf = ""
  var selectors = ast.newNode(nkBracket)
  var sawAny = false
  let pos = p.curr.col
  var selLine = p.curr.line
  var parenDepth = 0
  while p.curr.kind notin {tkLBrace, tkEOF} and p.curr.line == selLine:
    # Accumulate token text (identifiers, symbols, combinators, colons, dots, hashes, commas)
    let txt =
      if p.curr.value.len > 0: p.curr.value
      else: $p.curr.kind
    
    # Track paren depth so commas inside `:is(...)`, `:not(...)` etc. are not separators
    case p.curr.kind
    of tkLParen: inc parenDepth
    of tkRParen: dec parenDepth
    else: discard
    # When we hit a comma at depth 0, flush current buffer as one selector
    if p.curr.kind == tkComma and parenDepth <= 0:
      selectors.add(ast.newIdent(selBuf.strip()))
      selBuf = ""
      sawAny = true
      walk p # consume comma
      if p.curr.line == selLine + 1 and p.curr.kind notin {tkLBrace, tkEOF}:
        selLine = p.curr.line
      continue
    # Attribute selectors are collected whole to preserve quoting and operators
    if p.curr.kind == tkLBracket:
      selBuf &= p.collectAttributeSelector()
      sawAny = true
      continue
    # Add spacing only where the original source had whitespace (wsno > 0).
    # This preserves descendant combinators vs compound selectors (e.g. `[x] .a` vs `.a.b`)
    if selBuf.len > 0 and p.curr.wsno > 0:
      selBuf &= " "
    selBuf &= txt
    sawAny = true
    walk p

  
  # Flush last selector if any
  if selBuf.len > 0:
    selectors.add(ast.newIdent(selBuf.strip()))

  # Expect a selector block (properties) after selectors
  let propsBlock: Node = p.parseSelectorBlock(pos)
  caseNotNil propsBlock:
    # create selector node with selector strings and the block
    result = ast.newTree(nkElementSelector, selectors,
                ast.newEmpty(), ast.newEmpty(), propsBlock)

prefixHandle parseUniversalSelector:
  # parse the universal selector `*`, optionally followed by a compound
  # or descendant (e.g. `* html`, `* > .child`).
  let pos = p.curr.col
  walk p # tkAsterisk
  var selName = "*"
  while p.curr.kind notin {tkLBrace, tkEOF}:
    # compound-class continuation (no space): `*.foo`
    if p.curr.kind == tkDot and p.curr.wsno == 0:
      var rawSel = "*"
      while p.curr.kind notin {tkLBrace, tkEOF}:
        if p.curr.kind == tkLBracket:
          rawSel &= p.collectAttributeSelector()
          continue
        if rawSel.len > 0 and p.curr.wsno > 0:
          rawSel &= " "
        let txt =
          if p.curr.value.len > 0: p.curr.value
          else: $p.curr.kind
        rawSel &= txt
        walk p
      selName = rawSel
      break
    # descendant/combinator/other continuation: collect as raw
    if p.curr.kind in {tkPlus, tkGT, tkTilde, tkComma} or
       (p.curr.kind == tkDot and p.curr.wsno == 0) or
       (p.curr.line == p.prev.line and p.curr.wsno > 0 and
        p.curr.kind in {tkIdentifier, tkDot, tkHash, tkLBracket, tkColon, tkAsterisk}):
      var rawSel = "*"
      while p.curr.kind notin {tkLBrace, tkEOF}:
        if p.curr.kind == tkLBracket:
          rawSel &= p.collectAttributeSelector()
          continue
        if rawSel.len > 0 and p.curr.wsno > 0:
          rawSel &= " "
        let txt =
          if p.curr.value.len > 0: p.curr.value
          else: $p.curr.kind
        rawSel &= txt
        walk p
      selName = rawSel.strip()
      break
    break
  let selector = ast.newIdent(selName)
  let propsBlock: Node = p.parseSelectorBlock(pos)
  caseNotNil propsBlock:
    result = ast.newTree(nkElementSelector, selector,
                ast.newEmpty(), ast.newEmpty(), propsBlock)

prefixHandle parseHash:
  # Collect a hex color: #fff, #0d6efd, #123 (all attached tokens)
  var val = "#"
  walk p # tkHash
  while p.curr.kind in {tkIdentifier, tkInt, tkFloat} and p.curr.wsno == 0:
    val &= p.curr.value
    walk p
  if val.len == 1:
    val = "#"
  result = ast.newStringLit(val)

prefixHandle parseNot:
  walk p # tkKeywordNot
  let operand = p.parseExpression(minPrec = 90)
  caseNotNil operand:
    result = ast.newNode(nkPrefix)
    result.add(ast.newIdent("not"))
    result.add(operand)

prefixHandle parseArray:
  result = ast.newTree(nkArray)
  walk p # tkLBracket
  if p.curr.kind == tkRBracket:
    walk p # ]
    return
  while true:
    # object literal inside array: {k: v, ...}
    if p.curr.kind == tkLBrace:
      let elem = p.parseObjectStorage()
      if elem == nil:
        p.curr.error("expected object literal in array", fatal = true)
        break
      result.add(elem)
    else:
      let elem = p.parseExpression()
      if elem == nil:
        p.curr.error("expected expression in array", fatal = true)
        break
      result.add(elem)
    if p.curr.kind == tkComma:
      walk p # ,
      if p.curr.kind == tkRBracket:
        walk p # ]
        break
    elif p.curr.kind == tkRBracket:
      walk p # ]
      break
    elif p.curr.kind == tkEOF:
      p.curr.error("expected closing ']' for array", fatal = true)
      break
    else:
      p.curr.error("expected ',' or ']' in array", fatal = true)
      break

prefixHandle parseObjectStorage:
  # inline object {k: v, ...} used inside expressions (e.g. array of objects)
  result = ast.newTree(nkObjectStorage)
  walk p # tkLBrace
  if p.curr.kind == tkRBrace:
    walk p # }
    return
  while true:
    var keyNode: Node
    case p.curr.kind
    of tkIdentifier:
      keyNode = ast.newIdent(p.curr.value)
      keyNode.ln = p.curr.line
      keyNode.col = p.curr.col
      walk p
    of tkString:
      keyNode = ast.newStringLit(p.curr.value)
      walk p
    of tkInt, tkFloat:
      keyNode = p.parseNumber()
    else:
      p.curr.error("expected object key", fatal = true)
      break
    if p.curr.kind != tkColon:
      p.curr.error("expected ':' after object key", fatal = true)
      break
    walk p # tkColon
    let valNode = p.parseExpression()
    if valNode == nil:
      p.curr.error("expected value after ':'", fatal = true)
      break
    let colon = ast.newTree(nkColon, keyNode, valNode)
    colon.ln = keyNode.ln
    colon.col = keyNode.col
    result.add(colon)
    if p.curr.kind == tkComma:
      walk p # ,
      if p.curr.kind == tkRBrace:
        walk p # }
        break
    elif p.curr.kind == tkRBrace:
      walk p # }
      break
    elif p.curr.kind == tkEOF:
      p.curr.error("expected closing '}' for object", fatal = true)
      break
    else:
      p.curr.error("expected ',' or '}' in object", fatal = true)
      break

proc getPrefixFn(p: var Parser, minPrec: int): PrefixFunction =
  # Get the appropriate prefix function based on the current token.
  result = 
    case p.curr.kind
    of tkIdentifier:
      if p.next.line == p.curr.line and p.next is tkLParen:
        parseCall
      elif not p.inValue and not p.inForIterable and minPrec == 0 and
           not (p.curr.value.len > 0 and p.curr.value[0] == '$') and
           p.next.kind in {tkLBrace, tkDot, tkHash, tkColon} and p.next.line == p.curr.line and
           (not p.inBlockBody or p.next.kind == tkLBrace):
        parseSelector
      else: parseIdent
    of tkKeywordVar:
      # `var(...)` in CSS property values is a CSS function, not a declaration
      if p.next.kind == tkLParen and p.next.line == p.curr.line:
        collectRawCall
      else:
        parseVar
    of tkKeywordLet, tkKeywordConst: parseVar
    of tkCssVar: parseIdent
    of tkString: parseString
    of tkInt, tkFloat: parseNumber
    of tkMinus: parseMinus
    of tkPlus: parseUnaryPlus
    of tkKeywordTrue, tkKeywordFalse: parseBoolLit
    of tkKeywordNull: parseNullLit
    of tkKeywordFunction: parseFunction
    of tkKeywordIterator: parseIterator
    of tkKeywordWhile: parseWhile
    of tkKeywordReturn: parseReturn
    of tkKeywordBreak: parseBreak
    of tkKeywordContinue: parseContinue
    of tkKeywordEcho: parseEcho
    of tkKeywordIf: parseIf
    of tkKeywordFor: parseFor
    of tkKeywordCase: parseCase
    of tkKeywordNot: parseNot
    of tkLBracket: parseArray
    of tkDot: parseClassSelector
    of tkHash: parseHash
    of tkColon: parsePseudoSelector
    of tkAt: parseAtRule
    else: nil

proc parseExpression(p: var Parser, minPrec = 0): Node =
  var lhs = p.parsePrefix(minPrec)
  caseNotNil lhs:
    # Selectors and at-rules are complete statements — never infix operands
    if lhs.kind in {nkElementSelector, nkClassSelector, nkIdSelector, nkPseudoSelector, nkAtRule}:
      return lhs
    let startLn = lhs.ln
    let startCol = lhs.col
    while true:
      # handle infix operators
      # including dot and bracket access
      var
        opStr: string
        prec: int
        isBracket: bool
        isDot: bool
        isIs: bool
        isIsnot: bool
      
      if p.curr.line != lhs.ln:
        # if the next token is on a new line,
        # return the current expression
        return lhs

      # check for infix, dot, or bracket access operators
      case p.curr.kind
      of Operators, LogicalOperators:
        let inf = p.curr.kind.isInfix(minPrec)
        if not inf[0]: break
        opStr = inf[2].get()
        prec = inf[1]
      of tkKeywordIs:
        let inf = p.curr.kind.isInfix(minPrec)
        if not inf[0]: break
        opStr = inf[2].get()
        prec = inf[1]
        isIs = true
      of tkKeywordIsnot:
        let inf = p.curr.kind.isInfix(minPrec)
        if not inf[0]: break
        opStr = "isnot"
        prec = inf[1]
        isIsnot = true
      of tkDot:
        opStr = "."
        prec = getPrecedence(".")
        isDot = true
      of tkLBracket:
        opStr = "["
        prec = getPrecedence("[")
        isBracket = true
      else: break

      # Only continue if precedence is high enough
      if prec < minPrec: break
      
      walk p # consume operator
      if isBracket:
        # Parse bracket access: lhs[index]
        let indexNode = p.parseExpression()
        expectWalk tkRBracket
        lhs = ast.newNode(nkBracket).add([lhs, indexNode])
        lhs.ln = startLn; lhs.col = startCol
      elif isDot:
        # Parse dot access: lhs.rhs
        if p.curr is tkDot and p.curr.wsno == 0:
          # Handle double dot access `..`
          walk p # tkDot
          let rhs = p.parseExpression(minPrec = prec + 1)
          caseNotNil rhs:
            return ast.newCall(ast.newIdent(".."), lhs, rhs)
        let rhs = p.parseExpression(minPrec = prec + 1)
        lhs = ast.newTree(nkDot, lhs, rhs)
        lhs.ln = startLn; lhs.col = startCol
      elif isIs:
        # desugar `x is z` -> `is(x, z)`
        let rhs = p.parseExpression(minPrec = prec + 1)
        caseNotNil rhs:
          let callNode = ast.newCall(ast.newIdent("is"))
          callNode.add(lhs)
          callNode.add(rhs)
          callNode.ln = startLn; callNode.col = startCol
          lhs = callNode
      elif isIsnot:
        # desugar `x isnot z` -> `not is(x, z)`
        let rhs = p.parseExpression(minPrec = prec + 1)
        caseNotNil rhs:
          let callNode = ast.newCall(ast.newIdent("isnot"))
          callNode.add(lhs)
          callNode.add(rhs)
          callNode.ln = startLn; callNode.col = startCol
          lhs = callNode
      else:
        # Normal infix operator
        let rhs = p.parseExpression(minPrec = prec)
        lhs = ast.newInfix(ast.newIdent(opStr), lhs, rhs)
        lhs.ln = startLn; lhs.col = startCol
    result = lhs

prefixHandle parseObject:
  # parse an object
  result = ast.newTree(nkObject)
  if p.next is tkIdentifier:
    walk p # tkLitObject
    var id = ast.newIdent(p.curr.value)
    if p.next is tkAsterisk:
      id = ast.newNode(nkPostfix).add([ast.newIdent("*"), id])
      walk p, 2
    else:
      walk p # tkIdentifier
    expectWalk(tkLBrace) # expect a left curly brace
    # add the object identifier to the result
    # the empty node is used to define generic
    # parameters (todo)
    result.add([id, ast.newEmpty()])
    # parse the object fields
    var fields = newNode(nkRecFields)
    while true:
      case p.curr.kind
      of tkEOF:
        p.curr.error("expected closing '}' for object", fatal = true)
      of tkRBrace:
        walk p; break # end of the object
      of Strings + {tkIdentifier}:
        let identNode: Node = p.parseIdentDefs()
        caseNotNil identNode:
          fields.add(identNode)
        if p.curr is tkComma and p.next isnot tkRBrace:
          walk p # tkComma
      else: break # todo error
    result.add(fields)

prefixHandle parseStmt:
  let prefixFn: PrefixFunction =
    case p.curr.kind
    of tkDot: parseClassSelector
    of tkHash: parseIdSelector
    of tkAsterisk: parseUniversalSelector
    of tkColon: parsePseudoSelector
    of tkLBracket: parseSelector
    of tkKeywordVar, tkKeywordLet, tkKeywordConst: parseVar
    of tkKeywordFunction: parseFunction
    of tkKeywordIterator: parseIterator
    of tkKeywordMixin: parseMixin
    of tkKeywordWhile: parseWhile
    of tkKeywordEcho: parseEcho
    of tkIdentifier, tkCssVar:
      if p.next.line == p.curr.line and p.next is tkLParen:
        parseCall
      elif p.next.kind in {tkLBrace, tkComma, tkDot, tkHash, tkColon, tkLBracket} and p.next.line == p.curr.line and
           not (p.curr.value.len > 0 and p.curr.value[0] == '$') and not p.inForIterable:
        parseSelector
      elif p.next.line == p.curr.line and
           ((p.next.kind == tkIdentifier and p.next.wsno > 0) or
            p.next.kind in {tkPlus, tkGT, tkTilde}):
        parseSelector # element selector with descendant or combinator (e.g. `ol li`, `ol > li`)
      elif p.next.line != p.curr.line and p.next.col > p.curr.col and not p.inBlockBody:
        parseSelector # element selector with indented block (e.g. `hr` / `hr[role="x"]` alone on line)
      else: parseExpression
    of tkKeywordIf: parseIf
    of tkKeywordFor: parseFor
    of tkKeywordCase: parseCase
    of tkAt: parseAtRule
    of tkKeywordImport:
      proc (p: var Parser, minPrec = 0): Node =
        walk p # tkKeywordImport
        if p.curr.kind == tkString:
          result = ast.newTree(nkImport, ast.newStringLit(p.curr.value))
          walk p # tkString
        else:
          p.curr.error("import expects a string literal path")
    else: nil
  if prefixFn != nil:
    return prefixFn(p)

#
# Parse Script
#
proc parseScript*(astProgram: var Ast, code: sink string, sourcePath: string) =
  ## Parse the given code into an AST.
  var p = Parser(lex: newLexer(code))
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  astProgram = Ast()
  astProgram.sourcePath = sourcePath
  while p.curr.kind != tkEOF:
    # preserve top-level doc-block banners (license headers, section notes);
    # plain comments are skipped as before
    case p.curr.kind
    of tkDocBlock, tkDocBlockBang:
      astProgram.nodes.add(p.newCssComment())
      # consume trailing plain comments but keep further doc-block banners
      while p.curr.kind == tkComment:
        p.skipComments()
      continue
    of tkComment:
      p.skipComments()
      continue
    else: discard
    let node: Node = p.parseStmt()
    caseNotNil node:
      # reject bare literals/identifiers at document level — they produce no
      # CSS and usually indicate a typo (e.g. `$$$` or a stray number)
      if node.kind in {nkIdent, nkInt, nkFloat, nkString, nkBool}:
        p.curr.error("unexpected statement at document level", fatal = true)
      astProgram.nodes.add(node)
    do:
      p.curr.error(ErrUnexpectedToken % $p.curr.kind, fatal = true)