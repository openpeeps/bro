# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[strutils, options]

type
  TokenKind* = enum
    tkUnknown
    tkEOF
    tkIdentifier
    tkNumber
    tkString
    tkSemicolon = ";"
    tkColon = ":"
    tkComma = ","
    tkDot = "."
    tkHash = "#"
    tkLParen = "("
    tkRParen = ")"
    tkLBrace = "{"
    tkRBrace = "}"
    tkLBracket = "["
    tkRBracket = "]"
    tkPlus = "+"
    tkMinus = "-"
    tkAsterisk = "*"
    tkDivide = "/"
    tkPercent = "%"
    tkEqual = "="
    tkDoubleEqual = "=="
    tkNotEqual = "!="
    tkLT = "<"
    tkLTE = "<="
    tkGT = ">"
    tkGTE = ">="
    tkAnd = "&&"
    tkOr = "||"
    tkAssign = "="
    tkPlusAssign = "+="
    tkMinusAssign = "-="
    tkAsteriskAssign = "*="
    tkSlashAssign = "/="
    tkPercentAssign = "%="
    tkKeywordVar = "var"
    tkKeywordLet = "let"
    tkKeywordConst = "const"
    tkKeywordFunction = "function"
    tkKeywordReturn = "return"
    tkKeywordIf = "if"
    tkKeywordElse = "else"
    tkKeywordWhile = "while"
    tkKeywordFor = "for"
    tkKeywordIn = "in"
    tkKeywordOf = "of"
    tkKeywordBreak = "break"
    tkKeywordContinue = "continue"
    tkKeywordTrue = "true"
    tkKeywordFalse = "false"
    tkKeywordNull = "null"
    tkKeywordUndefined = "undefined"
    tkKeywordImport = "import"

    tkComment
    tkDocBlock


  TokenTuple* = tuple
    kind: TokenKind
    value: Option[string]
    line: int
    col: int
    pos: int
    wsno: int

  Lexer* = object
    input*: string
    pos*, line*, col*: int
    current*: char
    strbuf*: string # For building strings


proc newLexer*(input: string): Lexer =
  result.input = input
  result.pos = 0
  result.line = 1
  result.col = 0
  result.strbuf = ""
  if input.len > 0:
    result.current = input[0]
  else:
    result.current = '\0'

proc advance(lex: var Lexer) =
  if lex.pos < lex.input.len:
    if lex.current == '\n':
      inc lex.line
      lex.col = 0
    else:
      inc lex.col
    inc lex.pos
    if lex.pos < lex.input.len:
      lex.current = lex.input[lex.pos]
    else:
      lex.current = '\0'

proc peek(lex: Lexer, offset = 1): char =
  let idx = lex.pos + offset
  if idx < lex.input.len: lex.input[idx] else: '\0'

proc peekToken(lex: Lexer, expectToken: string): bool =
  # Peeks ahead to see if the next token matches expectToken
  # without advancing the lexer
  var tempLex = lex
  tempLex.strbuf.setLen(0)
  while tempLex.current.isAlphaAscii():
    tempLex.strbuf.add(tempLex.current)
    tempLex.advance()
  return tempLex.strbuf == expectToken

proc skipWhitespace(lex: var Lexer) =
  while lex.current in {' ', '\t', '\r'}:
    lex.advance()

proc initToken(lex: var Lexer, kind: static TokenKind, line, col, pos, wsno: int): TokenTuple =
  (kind, none(string), line, col, pos, wsno)

proc initToken(lex: var Lexer, value: sink string, kind: TokenKind, line, col, pos, wsno: int): TokenTuple =
  (kind, some(value), line, col, pos, wsno)

proc initToken(lex: var Lexer, kind: static TokenKind): TokenTuple =
  (kind, none(string), lex.line, lex.col, lex.pos, 0)

proc nextToken(lex: var Lexer): TokenTuple =
  # Retrieve the next token from the input
  var wsno = 0
  while true:
    while lex.current in {' ', '\t', '\r'}:
      inc wsno
      lex.advance()
    if lex.current == '\n' or lex.current == '\r':
      lex.advance()
      wsno = 0
      continue
    elif lex.current == '\r':
      if lex.peek() == '\n':
        lex.advance()
      inc lex.line
      lex.col = 0
      lex.advance()
      wsno = 0
      continue
    break
  let
    startLine = lex.line
    startCol = lex.col
    startPos = lex.pos
  case lex.current
  of '\0':
    result = initToken(lex, tkEOF, startLine, startCol, startPos, wsno)
  of ';':
    lex.advance()
    result = initToken(lex, tkSemicolon, startLine, startCol, startPos, wsno)
  of ':':
    lex.advance()
    result = initToken(lex, tkColon, startLine, startCol, startPos, wsno)
  of ',':
    lex.advance()
    result = initToken(lex, tkComma, startLine, startCol, startPos, wsno)
  of '.':
    lex.advance()
    result = initToken(lex, tkDot, startLine, startCol, startPos, wsno)
  of '#':
    lex.advance()
    result = initToken(lex, tkHash, startLine, startCol, startPos, wsno)
  of '(':
    lex.advance()
    result = initToken(lex, tkLParen, startLine, startCol, startPos, wsno)
  of ')':
    lex.advance()
    result = initToken(lex, tkRParen, startLine, startCol, startPos, wsno)
  of '{':
    lex.advance()
    result = initToken(lex, tkLBrace, startLine, startCol, startPos, wsno)
  of '}':
    lex.advance()
    result = initToken(lex, tkRBrace, startLine, startCol, startPos, wsno)
  of '[':
    lex.advance()
    result = initToken(lex, tkLBracket, startLine, startCol, startPos, wsno)
  of ']':
    lex.advance()
    result = initToken(lex, tkRBracket, startLine, startCol, startPos, wsno)
  of '+':
    lex.advance()
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkPlusAssign, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkPlus, startLine, startCol, startPos, wsno)
  of '-':
    lex.advance()
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkMinusAssign, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkMinus, startLine, startCol, startPos, wsno)
  of '*':
    lex.advance()
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkAsteriskAssign, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkAsterisk, startLine, startCol, startPos, wsno)
  of '/':
    lex.advance()
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkSlashAssign, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkDivide, startLine, startCol, startPos, wsno)
  of '%':
    lex.advance()
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkPercentAssign, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkPercent, startLine, startCol, startPos, wsno)
  of '=':
    lex.advance()
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkDoubleEqual, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkAssign, startLine, startCol, startPos, wsno)
  of '!':
    lex.advance()
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkNotEqual, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkUnknown, startLine, startCol, startPos, wsno)
  of '<':
    lex.advance()
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkLTE, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkLT, startLine, startCol, startPos, wsno)
  of '>':
    lex.advance()
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkGTE, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkGT, startLine, startCol, startPos, wsno)
  of '&':
    lex.advance()
    if lex.current == '&':
      lex.advance()
      result = initToken(lex, tkAnd, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkUnknown, startLine, startCol, startPos, wsno)
  of '|':
    lex.advance()
    if lex.current == '|':
      lex.advance()
      result = initToken(lex, tkOr, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkUnknown, startLine, startCol, startPos, wsno)
  of '"':
    lex.advance()
    lex.strbuf.setLen(0)
    while lex.current != '"' and lex.current != '\0':
      if lex.current == '\\':
        lex.advance()
        case lex.current
        of 'n': lex.strbuf.add('\n')
        of 't': lex.strbuf.add('\t')
        of 'r': lex.strbuf.add('\r')
        of '"': lex.strbuf.add('"')
        of '\\': lex.strbuf.add('\\')
        else: lex.strbuf.add(lex.current)
      else:
        lex.strbuf.add(lex.current)
      lex.advance()
    lex.advance() # skip closing "
    result = initToken(lex, move(lex.strbuf), tkString, startLine, startCol, startPos, wsno)
  of '0'..'9':
    lex.strbuf.setLen(0)
    while lex.current in {'0'..'9'}:
      lex.strbuf.add(lex.current)
      lex.advance()
    result = initToken(lex, lex.strbuf, tkNumber, startLine, startCol, startPos, wsno)
  of '$', '_':
    lex.strbuf.setLen(0)
    lex.strbuf.add(lex.current)
    lex.advance() # skip first char
    while lex.current.isAlphaNumeric() or lex.current in {'_', '-'}:
      lex.strbuf.add(lex.current)
      lex.advance()
    result = initToken(lex, move(lex.strbuf), tkIdentifier, startLine, startCol, startPos, wsno)
  else:
    if lex.current.isAlphaAscii() or lex.current in {'_', '-'}:
      lex.strbuf.setLen(0)
      while lex.current.isAlphaNumeric() or lex.current in {'_', '-'}:
        lex.strbuf.add(lex.current)
        lex.advance()
      result =
        case lex.strbuf
        of "var": initToken(lex, move(lex.strbuf), tkKeywordVar, startLine, startCol, startPos, wsno)
        of "let": initToken(lex, move(lex.strbuf), tkKeywordLet, startLine, startCol, startPos, wsno)
        of "const": initToken(lex, move(lex.strbuf), tkKeywordConst, startLine, startCol, startPos, wsno)
        of "function": initToken(lex, move(lex.strbuf), tkKeywordFunction, startLine, startCol, startPos, wsno)
        of "return": initToken(lex, move(lex.strbuf), tkKeywordReturn, startLine, startCol, startPos, wsno)
        of "if": initToken(lex, move(lex.strbuf), tkKeywordIf, startLine, startCol, startPos, wsno)
        of "else": initToken(lex, move(lex.strbuf), tkKeywordElse, startLine, startCol, startPos, wsno)
        of "while": initToken(lex, move(lex.strbuf), tkKeywordWhile, startLine, startCol, startPos, wsno)
        of "for": initToken(lex, move(lex.strbuf), tkKeywordFor, startLine, startCol, startPos, wsno)
        of "in": initToken(lex, move(lex.strbuf), tkKeywordIn, startLine, startCol, startPos, wsno)
        of "of": initToken(lex, move(lex.strbuf), tkKeywordOf, startLine, startCol, startPos, wsno)
        of "break": initToken(lex, move(lex.strbuf), tkKeywordBreak, startLine, startCol, startPos, wsno)
        of "continue": initToken(lex, move(lex.strbuf), tkKeywordContinue, startLine, startCol, startPos, wsno)
        of "true": initToken(lex, move(lex.strbuf), tkKeywordTrue, startLine, startCol, startPos, wsno)
        of "false": initToken(lex, move(lex.strbuf), tkKeywordFalse, startLine, startCol, startPos, wsno)
        of "null": initToken(lex, move(lex.strbuf), tkKeywordNull, startLine, startCol, startPos, wsno)
        of "undefined": initToken(lex, move(lex.strbuf), tkKeywordUndefined, startLine, startCol, startPos, wsno)
        of "import": initToken(lex, move(lex.strbuf), tkKeywordImport, startLine, startCol, startPos, wsno)
        else: initToken(lex, move(lex.strbuf), tkIdentifier, startLine, startCol, startPos, wsno)
    else:
      lex.advance()
      result = initToken(lex, tkUnknown, startLine, startCol, startPos, wsno)  

proc getToken*(lex: var Lexer): TokenTuple =
  ## Returns the next token from the input
  result = nextToken(lex)