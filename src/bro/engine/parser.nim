# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[strutils, tables, macros, options]
import pkg/voodoo/language/[errors, ast]

import ./lexer

type
  Parser* = object
    lex: Lexer
    prev, curr, next: TokenTuple
  
  BroParserError* = object of ValueError
    file: string
    ln, col: int

const
  MathOperators = {tkPlus, tkMinus, tkAsterisk, tkDivide}
  LogicalOperators = {tkAnd, tkOr}
  ComparisonOperators = {tkDoubleEqual, tkNotEqual, tkGT, tkGTE, tkLT, tkLTE}
  Operators = ComparisonOperators + MathOperators + {tkAssign}
  Strings = {tkString}
  Assignables = {tkKeywordTrue, tkKeywordFalse, tkNumber, tkIdentifier} + Strings

proc error(tk: TokenTuple, msg: string) =
  ## Raise a parsing error on the given node.
  raise (ref BroParserError)(
          # file: node.file,
          ln: tk.line,
          col: tk.col,
          msg: ErrorFmt % ["", $tk.line, $tk.col, msg])


const
  infixTokenTable = {
    tkPlus: "+",
    tkMinus: "-",
    tkAsterisk: "*",
    tkDivide: "/",
    tkGT: ">",
    tkGTE: ">=",
    tkLT: "<",
    
    tkLTE: "<=",
    tkDoubleEqual: "==",
    tkNotEqual: "!=",
    tkAnd: "&&",
    tkAssign: "=",
    tkDot: ".",
    tkLBracket: "["
  }.toTable

  logicalOperators = {
    tkAnd: "&&",
    tkOr: "||",
  }.toTable

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
  # elif p.curr.line == p.prev.line:
    # p.curr.error(ErrBadIndentation)

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
proc getPrecedence(op: string): int =
  # Get the precedence of an operator
  # Returns 0 if the operator is not found
  if op in OperatorPrecedence: OperatorPrecedence[op]
  else: 0

proc isInfix(kind: TokenKind, minPrec = 0): (bool, int, Option[string]) =
  # Check if the token kind is an infix operator
  var opStr: string
  if infixTokenTable.hasKey(kind):
    opStr = infixTokenTable[kind]
  elif logicalOperators.hasKey(kind):
    opStr = logicalOperators[kind]
  else: return # default
  let prec = getPrecedence(opStr)
  result = (prec > minPrec, prec, some(opStr))

#
# Parse handlers
#
prefixHandle parseIdent:
  # parse an identifier
  result = ast.newIdent(p.curr.value.get())
  walk p # tkIdentifier

prefixHandle parseCall:
  # parse a function call
  result = ast.newCall(ast.newIdent(p.curr.value.get()))
  walk p # tkIdentifier
  # parse function arguments wrapped in parentheses
  # and mark expectRP as true to expect a closing parenthesis
  var expectRP = p.curr.kind == tkLParen
  if expectRP: walk p # tkLParen
  if p.curr isnot tkRParen:
    while true:
      if p.curr.kind == tkIdentifier and p.next.kind == tkAssign:
        # parse a named argument
        let name = ast.newIdent(p.curr.value.get())
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
      
      # checking for the next token
      case p.curr.kind
      of tkComma:
        walk p # skip to next argument
      of tkRParen:
        if expectRP:
          walk p # tkRParen
        break
      of tkEOF:
        break # todo error EOF before closing parenthesis
      else: break
  else: walk p # tkRParen

prefixHandle parseString:
  # parse a string
  result = ast.newStringLit(p.curr.value.get())
  walk p

prefixHandle parseBoolLit:
  # parse a boolean literal
  result = ast.newBoolLit(p.curr.kind == tkKeywordTrue)
  walk p

const unitSizeSuffixes = ["px", "em", "rem", "%", "vh", "vw", "vmin", "vmax"]

prefixHandle parseNumber:
  # parse a number
  let num = p.curr
  result =
    try:
      ast.newIntLit(parseInt(num.value.get()))
    except ValueError:
      nil
  if result == nil:
    result =
      try:
        ast.newFloatLit(parseFloat(num.value.get()))
      except ValueError:
        nil
  if result == nil: discard # todo error
  if p.next.kind == tkIdentifier and (p.next.line == num.line and p.next.wsno == 0):
    # handle unit suffixes for numbers, e.g., `10px`, `2em`, etc.
    walk p # consume the number token
    let suffix = p.curr.value.get()
    if suffix in unitSizeSuffixes:
      result = ast.newNode(nkUnit).add([result, ast.newIdent(suffix)])
  walk p # consume the number token (or the unit suffix if it exists)

prefixHandle parsePrefix:
  let parseFn = p.getPrefixFn(minPrec)
  if parseFn != nil: 
    return parseFn(p)

proc createIdentNode(p: var Parser): Node {.rule.} = 
  result = ast.newIdent(p.curr.value.get())
  walk p # tkIdentifier

proc getVarIdent(p: var Parser, varIdent: bool): Node {.rule.} =
  # get the identifier name from the current token
  result = p.createIdentNode()
  if varIdent:
    # variable definitions can be suffixed with an asterisk
    # to mark them as exported (public)
    if p.curr is tkAsterisk:
      walk p
      return ast.newNode(nkPostfix).add([ast.newIdent("*"), result])

proc parseIdentDefs(p: var Parser, varIdent = true): Node {.rule.} =
  ## Parse identifier definitions
  result = newNode(nkIdentDefs)
  if p.curr.kind == tkIdentifier:
    let identNode = p.getVarIdent(varIdent)
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
            ty.varType = ast.newIdent(p.next.value.get())
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
  result.add(p.parseIdentDefs(true))
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
    name = ast.newIdent(p.curr.value.get())
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
      walk p; break # tkRBrace
    elif not closingBlock and p.curr.col <= indentPos: break
    let subNode = p.parseExpression()
    caseNotNil subNode:
      stmts.add(subNode)
  result = ast.newTree(nkBlock, stmts)

proc parseSelectorBlock(p: var Parser, indentPos = 0): Node {.rule.} =
  # parse a block of properties for a class selector
  var
    closingBlock: bool
    props = newSeq[Node](0)
  if p.curr is tkLBrace:
    closingBlock = true
    walk p # tkLBrace
  else:
    closingBlock = false
  while p.curr isnot tkEOF:
    if closingBlock and p.curr is tkRBrace:
      walk p; break # tkRBrace
    elif not closingBlock and p.curr.col <= indentPos:
      break
    # parse property definitions, which are similar to
    # variable declarations but without the `var` keyword
    case p.curr.kind
    of tkIdentifier:
      if p.next.kind == tkColon:
        # parse a CSS property definition, e.g., `color: red;`
        # the semicolon is optional, so we handle it in the
        # walkOptSemiColon call after parsing the property value
        let propName = ast.newIdent(p.curr.value.get())
        walk p, 2 # tkIdentifier > tkColon
        let propValue = p.parseExpression()
        caseNotNil propValue:
          let propNode = ast.newTree(nkColon, propName, propValue)
          props.add(propNode)
        p.walkOptSemiColon() # optional semicolon after each property
    else:
      # we allow for nested CSS selectors and other
      # statements in the selector block, so we parse them as expressions
      let subNode = p.parseExpression()
      caseNotNil subNode:
        props.add(subNode)
  result = ast.newTree(nkBlock, props)

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

prefixHandle parseIf:
  # parse an if statement
  let tk = p.curr
  walk p # tkKeywordIf
  expectWalk tkLParen
  let ifExpr = p.parseExpression()
  caseNotNil ifExpr:
    expectWalk tkRParen
    var children = @[ifExpr]
    let ifBlock: Node = p.parseBlock(tk.col)
    caseNotNil ifBlock:
      children.add(ifBlock)
    # handle elif statements
    while true:
      if p.curr.kind == tkKeywordElse and p.next.kind == tkKeywordIf:
        walk p, 2 # tkKeywordElse, tkKeywordIf
        expectWalk tkLParen
        let elifExpr = p.parseExpression()
        caseNotNil elifExpr:
          expectWalk tkRParen
          let elifBlock = p.parseBlock(tk.col)
          caseNotNil elifBlock:
            children.add(@[elifExpr, elifBlock])
      elif p.curr.kind == tkKeywordElse:
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
      itemVar.add(ast.newIdent(p.curr.value.get()))
      walk p, 2 # tkComma
      itemVar.add(ast.newIdent(p.curr.value.get()))
    else:
      itemVar = ast.newIdent(p.curr.value.get())
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
    let selector = ast.newIdent(p.curr.value.get())
    walk p # tkIdentifier
    let propsBlock: Node = p.parseSelectorBlock(pos)
    caseNotNil propsBlock:
      result = ast.newTree(nkClassSelector, selector,
                  ast.newEmpty(), ast.newEmpty(), propsBlock)
  else: return nil

prefixHandle parseIdSelector:
  # parse an ID selector, which is a hash followed by an identifier
  let pos = p.curr.col
  walk p # tkDot
  if p.curr.kind == tkIdentifier:
    let selector = ast.newIdent(p.curr.value.get())
    walk p # tkIdentifier
    let propsBlock: Node = p.parseSelectorBlock(pos)
    caseNotNil propsBlock:
      result = ast.newTree(nkIdSelector, selector,
                    ast.newEmpty(), ast.newEmpty(), propsBlock)
  else: return nil

proc getPrefixFn(p: var Parser, minPrec: int): PrefixFunction =
  # Get the appropriate prefix function based on the current token.
  result = 
    case p.curr.kind
    of tkIdentifier:
      if p.next.line == p.curr.line and p.next is tkLParen:
        parseCall
      else: parseIdent
    of tkKeywordVar, tkKeywordLet, tkKeywordConst: parseVar
    of tkString: parseString
    of tkNumber: parseNumber
    of tkKeywordTrue, tkKeywordFalse: parseBoolLit
    of tkKeywordFunction: parseFunction
    of tkKeywordReturn: parseReturn
    of tkKeywordBreak: parseBreak
    of tkKeywordContinue: parseContinue
    of tkKeywordIf: parseIf
    of tkKeywordFor: parseFor
    of tkDot: parseClassSelector
    of tkHash: parseIdSelector
    else: nil

proc parseExpression(p: var Parser, minPrec = 0): Node =
  var lhs = p.parsePrefix(minPrec)
  caseNotNil lhs:
    while true:
      # handle infix operators
      # including dot and bracket access
      var
        opStr: string
        prec: int
        isBracket = false
        isDot = false
      
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
      else:
        # Normal infix operator
        let rhs = p.parseExpression(minPrec = prec)
        lhs = ast.newInfix(ast.newIdent(opStr), lhs, rhs)
    result = lhs

prefixHandle parseObject:
  # parse an object
  result = ast.newTree(nkObject)
  if p.next is tkIdentifier:
    walk p # tkLitObject
    var id = ast.newIdent(p.curr.value.get())
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
      of tkEOF: break
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
    of tkKeywordVar, tkKeywordLet, tkKeywordConst: parseVar
    of tkKeywordFunction: parseFunction
    of tkIdentifier:
      if p.next.line == p.curr.line and p.next is tkLParen:
        parseCall
      else: parseExpression
    of tkKeywordIf: parseIf
    of tkKeywordFor: parseFor
    else: nil
  if prefixFn != nil: return prefixFn(p)

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
    let node: Node = p.parseStmt()
    caseNotNil node:
      astProgram.nodes.add(node)
    do:
      p.curr.error(ErrUnexpectedToken % $p.curr.kind)