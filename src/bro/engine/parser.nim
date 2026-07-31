# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[strutils, tables, macros, options]
import pkg/vancode/interpreter/[errors, ast]

import ./lexer

type
  Parser* = object
    lex: Lexer
    prev, curr, next: TokenTuple
    inValue*: bool # when true, identifiers are parsed as CSS values, not selectors
  
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
  while p.curr isnot tkEOF:
    if closingBlock and p.curr is tkRBrace:
      walk p; closed = true; break # tkRBrace
    elif not closingBlock and p.curr.col <= indentPos: break
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
    let exprNode = p.parseExpression()
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
  let curLine = p.curr.line
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
      continue
    if p.curr.kind == tkLBracket:
      selBuf &= p.collectAttributeSelector()
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
  if p.curr.kind == tkIdentifier:
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
  while p.curr isnot tkEOF:
    p.skipComments() # skip comments between properties
    if closingBlock and p.curr is tkRBrace:
      walk p; closed = true; break # tkRBrace
    elif not closingBlock and p.curr.col <= indentPos:
      break
    # parse property definitions, which are similar to
    # variable declarations but without the `var` keyword
    case p.curr.kind
    of tkIdentifier, tkCssVar:
      if p.next.kind == tkColon:
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
      elif p.next.line == p.curr.line and p.next.kind == tkIdentifier and p.next.wsno > 0:
        # element selector with descendant, e.g. `ol li`
        let subNode = p.parseBlockSelector(p.curr.col)
        caseNotNil subNode:
          props.add(subNode)
      else:
        let subNode = p.parseExpression()
        caseNotNil subNode:
          props.add(subNode)
    of tkDot, tkHash, tkColon, tkLBracket:
      let subNode = p.parseBlockSelector(p.curr.col)
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

prefixHandle parseIf:
  # parse an if statement
  let tk = p.curr
  walk p # tkKeywordIf
  let ifExpr = p.parseExpression()
  caseNotNil ifExpr:
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
          let elifBlock = p.parseBlock(tk.col)
          caseNotNil elifBlock:
            children.add(@[elifExpr, elifBlock])
      elif p.curr.kind == tkKeywordElse:
        if p.curr.col != tk.col:
          break
        walk p # tkKeywordElse
        let elseBlock = p.parseBlock(tk.col)
        caseNotNil elseBlock:
          children.add(elseBlock)
      else: break
    result = ast.newTree(nkIf, children)

prefixHandle parseFor:
  # parse a for loop
  let tokenFor: TokenTuple = p.curr
  if p.next.kind == tkIdentifier:
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
    let iterExpr: Node = p.parseExpression() 
    caseNotNil iterExpr:
      let body: Node = p.parseBlock(tokenFor.col)
      caseNotNil body:
        result = ast.newTree(nkFor, itemVar, iterExpr, body)

prefixHandle parseClassSelector:
  # parse a class selector, which is a dot followed by an identifier
  let pos = p.curr.col
  walk p # tkDot
  if p.curr.kind == tkIdentifier:
    var selName = p.curr.value
    walk p # tkIdentifier
    while p.curr.kind == tkColon and p.curr.line == p.prev.line and p.curr.wsno == 0:
      selName &= p.collectPseudoSuffix()
    # handle attribute selectors like [data-x="y"] appended to class
    while p.curr.kind == tkLBracket and p.curr.line == p.prev.line:
      selName &= p.collectAttributeSelector()
    # Compound classes (.foo.bar), combinators, or descendants collect as raw text
    if p.curr.kind in {tkPlus, tkGT, tkTilde, tkComma} or
       (p.curr.kind == tkDot and p.curr.wsno == 0) or
       (p.curr.line == p.prev.line and p.curr.wsno > 0 and p.curr.kind in {tkIdentifier, tkDot, tkHash, tkLBracket, tkColon, tkAsterisk}):
      var rawSel = "." & selName
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
    if p.curr.kind in {tkPlus, tkGT, tkTilde, tkComma} or
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
  # parse a pseudo selector like `:root`
  let pos = p.curr.col
  walk p # tkColon
  if p.curr.kind == tkIdentifier and p.curr.value == "root":
    var selName = p.curr.value
    walk p # tkIdentifier
    # handle attribute selectors like [data-x] appended to pseudo
    while p.curr.kind == tkLBracket and p.curr.line == p.prev.line:
      selName &= p.collectAttributeSelector()
    if p.curr.kind in {tkPlus, tkGT, tkTilde, tkComma} or
       (p.curr.kind == tkDot and p.curr.wsno == 0) or
       (p.curr.line == p.prev.line and p.curr.wsno > 0 and p.curr.kind in {tkIdentifier, tkDot, tkHash, tkLBracket, tkColon, tkAsterisk}):
      var rawSel = ":" & selName
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
        result = ast.newTree(nkPseudoSelector, selector,
                    ast.newEmpty(), ast.newEmpty(), propsBlock)

proc parseAtRulePrelude(p: var Parser, atLine: int): string =
  var prelude = ""
  while p.curr.kind notin {tkLBrace, tkSemicolon, tkEOF} and p.curr.line == atLine:
    let txt =
      if p.curr.value.len > 0: p.curr.value
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
    case p.curr.kind
    of tkIdentifier:
      if p.curr.value in ["from", "to"]:
        selectorName = p.curr.value
        walk p
      else:
        break
    of tkInt, tkFloat:
      selectorName = p.curr.value
      walk p
      if p.curr.kind == tkPercent:
        selectorName &= "%"
        walk p
    else:
      break
    if selectorName.len == 0:
      break
    let selBlock = p.parseSelectorBlock(selCol)
    caseNotNil selBlock:
      let sel = ast.newNode(nkBracket)
      sel.add(ast.newIdent(selectorName))
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
  var parenDepth = 0
  while p.curr.kind notin {tkLBrace, tkEOF}:
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

proc getPrefixFn(p: var Parser, minPrec: int): PrefixFunction =
  # Get the appropriate prefix function based on the current token.
  result = 
    case p.curr.kind
    of tkIdentifier:
      if p.next.line == p.curr.line and p.next is tkLParen:
        parseCall
      elif not p.inValue and p.next.kind in {tkLBrace, tkDot, tkHash, tkColon} and p.next.line == p.curr.line:
        parseSelector
      else: parseIdent
    of tkKeywordVar:
      # `var(...)` in CSS property values is a function call, not a declaration
      if p.next.kind == tkLParen and p.next.line == p.curr.line:
        parseCall
      else:
        parseVar
    of tkKeywordLet, tkKeywordConst: parseVar
    of tkCssVar: parseIdent
    of tkString: parseString
    of tkInt, tkFloat: parseNumber
    of tkMinus: parseMinus
    of tkKeywordTrue, tkKeywordFalse: parseBoolLit
    of tkKeywordNull: parseNullLit
    of tkKeywordFunction: parseFunction
    of tkKeywordIterator: parseIterator
    of tkKeywordWhile: parseWhile
    of tkKeywordReturn: parseReturn
    of tkKeywordBreak: parseBreak
    of tkKeywordContinue: parseContinue
    of tkKeywordIf: parseIf
    of tkKeywordFor: parseFor
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
    of tkColon: parsePseudoSelector
    of tkLBracket: parseSelector
    of tkKeywordVar, tkKeywordLet, tkKeywordConst: parseVar
    of tkKeywordFunction: parseFunction
    of tkKeywordIterator: parseIterator
    of tkKeywordWhile: parseWhile
    of tkIdentifier, tkCssVar:
      if p.next.line == p.curr.line and p.next is tkLParen:
        parseCall
      elif p.next.kind in {tkLBrace, tkComma, tkDot, tkHash, tkColon, tkLBracket} and p.next.line == p.curr.line:
        parseSelector
      elif p.next.line == p.curr.line and
           ((p.next.kind == tkIdentifier and p.next.wsno > 0) or
            p.next.kind in {tkPlus, tkGT, tkTilde}):
        parseSelector # element selector with descendant or combinator (e.g. `ol li`, `ol > li`)
      else: parseExpression
    of tkKeywordIf: parseIf
    of tkKeywordFor: parseFor
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
  p.skipComments()
  astProgram = Ast()
  astProgram.sourcePath = sourcePath
  while p.curr.kind != tkEOF:
    try:
      let node: Node = p.parseStmt()
      caseNotNil node:
        astProgram.nodes.add(node)
      do:
        p.curr.error(ErrUnexpectedToken % $p.curr.kind)
    except BroParserError as e:
      if e.fatal:
        raise e # fatal syntax errors abort parsing
      # skip the bad token and continue from the next one
      if p.curr.kind notin {tkEOF}:
        walk(p)