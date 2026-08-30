# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/strutils

type
  TokenKind* = enum
    tkUnknown
    tkEOF
    tkIdentifier
    tkCssVar # css custom property, e.g. --my-var
    tkInt
    tkFloat
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
    tkAmp = "&"
    tkAndAnd = "&&"
    tkOrOr = "||"
    tkOr = "or"
    tkKeywordIs = "is"
    tkKeywordIsnot = "isnot"
    tkAnd = "and"
    tkKeywordNot = "not"
    tkBacktick = "`"
    tkAt = "@"
    tkAssign = "="
    tkPlusAssign = "+="
    tkMinusAssign = "-="
    tkAsteriskAssign = "*="
    tkSlashAssign = "/="
    tkPercentAssign = "%="
    tkBang = "!"
    tkTilde = "~"
    tkTildeAssign = "~="
    tkCaret = "^"
    tkCaretAssign = "^="
    tkPipeAssign = "|="
    tkDollarAssign = "$="
    tkKeywordVar = "var"
    tkKeywordLet = "let"
    tkKeywordConst = "const"
    tkKeywordFunction = "function"
    tkKeywordReturn = "return"
    tkKeywordIf = "if"
    tkKeywordElse = "else"
    tkKeywordElif = "elif"
    tkKeywordWhile = "while"
    tkKeywordFor = "for"
    tkKeywordIn = "in"
    tkKeywordOf = "of"
    tkKeywordCase = "case"
    tkKeywordBreak = "break"
    tkKeywordContinue = "continue"
    tkKeywordEcho = "echo"
    tkKeywordTrue = "true"
    tkKeywordFalse = "false"
    tkKeywordNull = "null"
    tkKeywordUndefined = "undefined"
    tkKeywordImport = "import"
    tkKeywordIterator = "iterator"
    tkKeywordMixin = "mixin"

    tkComment
    tkDocBlock
    tkDocBlockBang


  TokenTuple* = tuple
    kind: TokenKind
    value: string
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

proc peek*(lex: Lexer, offset = 1): char =
  let idx = lex.pos + offset
  if idx < lex.input.len: lex.input[idx] else: '\0'

proc peekToken*(lex: Lexer, expectToken: string): bool =
  # Peeks ahead to see if the next token matches expectToken
  # without advancing the lexer
  var tempLex = lex
  tempLex.strbuf.setLen(0)
  while tempLex.current.isAlphaAscii():
    tempLex.strbuf.add(tempLex.current)
    tempLex.advance()
  return tempLex.strbuf == expectToken

proc skipWhitespace*(lex: var Lexer) =
  while lex.current in {' ', '\t', '\r'}:
    lex.advance()

proc initToken*(lex: var Lexer, kind: static TokenKind, line, col, pos, wsno: int): TokenTuple =
  (kind, "", line, col, pos, wsno)

proc initToken*(lex: var Lexer, value: sink string, kind: TokenKind, line, col, pos, wsno: int): TokenTuple =
  (kind, value, line, col, pos, wsno)

proc initToken*(lex: var Lexer, kind: static TokenKind): TokenTuple =
  (kind, "", lex.line, lex.col, lex.pos, 0)

proc tryLexExponent(lex: var Lexer): bool =
  ## Consume a scientific-notation exponent (`e10`, `E+5`, `e-2`) into strbuf
  ## when one follows the mantissa. Returns true if an exponent was consumed.
  if lex.current notin {'e', 'E'}:
    return false
  let c1 = peek(lex, 1)
  if not (c1.isDigit() or (c1 in {'+', '-'} and peek(lex, 2).isDigit())):
    return false
  lex.strbuf.add(lex.current)
  lex.advance() # consume 'e'/'E'
  if lex.current in {'+', '-'}:
    lex.strbuf.add(lex.current)
    lex.advance()
  while lex.current.isDigit():
    lex.strbuf.add(lex.current)
    lex.advance()
  result = true

proc nextToken(lex: var Lexer): TokenTuple =
  # Retrieve the next token from the input
  var wsno = 0
  while true:
    while lex.current in {' ', '\t'}:
      inc wsno
      lex.advance()
    if lex.current == '\n':
      lex.advance()
      wsno = 0
      continue
    elif lex.current == '\r':
      lex.advance()
      if lex.current == '\n':
        lex.advance()
      else:
        inc lex.line
      lex.col = 0
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
    if peek(lex).isDigit():
      # leading-dot float: .125, .5rem, .5e2
      lex.strbuf.setLen(0)
      lex.strbuf.add("0.")
      lex.advance() # consume '.'
      while lex.current in {'0'..'9'}:
        lex.strbuf.add(lex.current)
        lex.advance()
      discard tryLexExponent(lex)
      result = initToken(lex, lex.strbuf, tkFloat, startLine, startCol, startPos, wsno)
    else:
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
    # CSS custom property: starts with `--`
    if peek(lex) == '-':
      # consume both '-' characters
      lex.advance() # first '-'
      lex.advance() # second '-'
      lex.strbuf.setLen(0)
      # allow letters, digits, underscores and hyphens in the rest of the name
      while lex.current.isAlphaNumeric() or lex.current in {'_', '-'}:
        lex.strbuf.add(lex.current)
        lex.advance()
      var val = if lex.strbuf.len > 0: "--" & lex.strbuf else: "--"
      result = initToken(lex, move(val), tkCssVar, startLine, startCol, startPos, wsno)
    elif peek(lex).isAlphaAscii():
      # vendor-prefixed identifier: -webkit-..., -moz-..., -ms-...
      lex.strbuf.setLen(0)
      lex.strbuf.add('-')
      lex.advance() # consume '-'
      while lex.current.isAlphaNumeric() or lex.current in {'_', '-'}:
        lex.strbuf.add(lex.current)
        lex.advance()
      result = initToken(lex, move(lex.strbuf), tkIdentifier, startLine, startCol, startPos, wsno)
    elif peek(lex).isDigit():
      # negative number: -0.375, -5, -1e2  (single token so `-0.375rem -0.75rem` are two values)
      lex.strbuf.setLen(0)
      lex.strbuf.add('-')
      lex.advance() # consume '-'
      while lex.current in {'0'..'9'}:
        lex.strbuf.add(lex.current)
        lex.advance()
      var isFloat = false
      if lex.current == '.' and peek(lex).isDigit():
        lex.strbuf.add('.')
        lex.advance() # consume '.'
        while lex.current in {'0'..'9'}:
          lex.strbuf.add(lex.current)
          lex.advance()
        isFloat = true
      if tryLexExponent(lex):
        isFloat = true
      if isFloat:
        result = initToken(lex, lex.strbuf, tkFloat, startLine, startCol, startPos, wsno)
      else:
        result = initToken(lex, lex.strbuf, tkInt, startLine, startCol, startPos, wsno)
    else:
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
    # handle divide, assignment, and comments:
    lex.advance() # moved past '/'
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkSlashAssign, startLine, startCol, startPos, wsno)
    elif lex.current == '/':
      # single-line comment: '//' ... until newline (don't consume newline here)
      lex.advance() # move to first char of comment body
      lex.strbuf.setLen(0)
      while lex.current != '\n' and lex.current != '\r' and lex.current != '\0':
        lex.strbuf.add(lex.current)
        lex.advance()
      result = initToken(lex, move(lex.strbuf), tkComment, startLine, startCol, startPos, wsno)
    elif lex.current == '*':
      # block comment: '/* ... */' and docblocks '/** ... */' or '/*! ... */'
      # (banner convention for license headers that must survive minification)
      let isBang = peek(lex, 1) == '!'
      let isDoc = peek(lex, 1) == '*' or isBang
      # consume the '*' we are currently on, then collect until '*/' or EOF
      lex.advance()
      lex.strbuf.setLen(0)
      while not (lex.current == '*' and peek(lex) == '/') and lex.current != '\0':
        lex.strbuf.add(lex.current)
        lex.advance()
      # consume closing '*/' if present
      if lex.current == '*' and peek(lex) == '/':
        lex.advance() # '*'
        lex.advance() # '/'
      result = initToken(lex, move(lex.strbuf),
        if isBang: tkDocBlockBang elif isDoc: tkDocBlock else: tkComment,
        startLine, startCol, startPos, wsno)
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
      result = initToken(lex, tkBang, startLine, startCol, startPos, wsno)
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
      result = initToken(lex, tkAndAnd, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkAmp, startLine, startCol, startPos, wsno)
  of '|':
    lex.advance()
    if lex.current == '|':
      lex.advance()
      result = initToken(lex, tkOrOr, startLine, startCol, startPos, wsno)
    elif lex.current == '=':
      lex.advance()
      result = initToken(lex, tkPipeAssign, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkUnknown, startLine, startCol, startPos, wsno)
  of '"', '\'':
    let quote = lex.current
    lex.advance()
    lex.strbuf.setLen(0)
    while lex.current != quote and lex.current != '\0':
      if lex.current == '\\':
        lex.advance()
        case lex.current
        of 'n': lex.strbuf.add('\n')
        of 't': lex.strbuf.add('\t')
        of 'r': lex.strbuf.add('\r')
        of '"': lex.strbuf.add('"')
        of '\'': lex.strbuf.add('\'')
        of '\\': lex.strbuf.add('\\')
        else:
          # CSS strings: preserve the backslash for unrecognized escapes
          # e.g. `\201E` → `\201E`, `\3B` → `\3B`
          lex.strbuf.add('\\')
          lex.strbuf.add(lex.current)
      else:
        lex.strbuf.add(lex.current)
      lex.advance()
    lex.advance() # skip closing quote
    result = initToken(lex, move(lex.strbuf), tkString, startLine, startCol, startPos, wsno)
  of '0'..'9':
    lex.strbuf.setLen(0)
    # integer part
    while lex.current in {'0'..'9'}:
      lex.strbuf.add(lex.current)
      lex.advance()
    var isFloat = false
    # fractional part?
    if lex.current == '.' and peek(lex).isDigit():
      lex.strbuf.add('.')
      lex.advance() # consume '.'
      while lex.current in {'0'..'9'}:
        lex.strbuf.add(lex.current)
        lex.advance()
      isFloat = true
    # scientific notation? e.g. 1e3, 2.5E-2
    if tryLexExponent(lex):
      isFloat = true
    if isFloat:
      result = initToken(lex, lex.strbuf, tkFloat, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, lex.strbuf, tkInt, startLine, startCol, startPos, wsno)

  of '$':
    if peek(lex) == '=':
      lex.advance()
      lex.advance()
      result = initToken(lex, tkDollarAssign, startLine, startCol, startPos, wsno)
    else:
      lex.strbuf.setLen(0)
      lex.strbuf.add(lex.current)
      lex.advance() # skip first char
      while lex.current.isAlphaNumeric() or lex.current in {'_', '-'}:
        lex.strbuf.add(lex.current)
        lex.advance()
      result = initToken(lex, move(lex.strbuf), tkIdentifier, startLine, startCol, startPos, wsno)
  of '_':
    lex.strbuf.setLen(0)
    lex.strbuf.add(lex.current)
    lex.advance() # skip first char
    while lex.current.isAlphaNumeric() or lex.current in {'_', '-'}:
      lex.strbuf.add(lex.current)
      lex.advance()
    result = initToken(lex, move(lex.strbuf), tkIdentifier, startLine, startCol, startPos, wsno)
  of '~':
    lex.advance()
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkTildeAssign, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkTilde, startLine, startCol, startPos, wsno)
  of '^':
    lex.advance()
    if lex.current == '=':
      lex.advance()
      result = initToken(lex, tkCaretAssign, startLine, startCol, startPos, wsno)
    else:
      result = initToken(lex, tkCaret, startLine, startCol, startPos, wsno)
  of '`':
    lex.advance()
    lex.strbuf.setLen(0)
    while lex.current != '`' and lex.current != '\0' and lex.current != '\n':
      lex.strbuf.add(lex.current)
      lex.advance()
    if lex.current == '`':
      lex.advance()
    result = initToken(lex, move(lex.strbuf), tkBacktick, startLine, startCol, startPos, wsno)
  of '@':
    lex.advance()
    result = initToken(lex, tkAt, startLine, startCol, startPos, wsno)
  else:
    if lex.current.isAlphaAscii() or lex.current in {'_', '-'}:
      lex.strbuf.setLen(0)
      while lex.current.isAlphaNumeric() or lex.current in {'_', '-'}:
        lex.strbuf.add(lex.current)
        lex.advance()
      result =
        case lex.strbuf
        of "var": initToken(lex, move(lex.strbuf), tkKeywordVar, startLine, startCol, startPos, wsno)
        of "fn", "func", "function":
          # `fn` / `func` are canonical aliases for `function`
          initToken(lex, move(lex.strbuf), tkKeywordFunction, startLine, startCol, startPos, wsno)
        of "let": initToken(lex, move(lex.strbuf), tkKeywordLet, startLine, startCol, startPos, wsno)
        of "const": initToken(lex, move(lex.strbuf), tkKeywordConst, startLine, startCol, startPos, wsno)
        of "return": initToken(lex, move(lex.strbuf), tkKeywordReturn, startLine, startCol, startPos, wsno)
        of "if": initToken(lex, move(lex.strbuf), tkKeywordIf, startLine, startCol, startPos, wsno)
        of "else": initToken(lex, move(lex.strbuf), tkKeywordElse, startLine, startCol, startPos, wsno)
        of "elif": initToken(lex, move(lex.strbuf), tkKeywordElif, startLine, startCol, startPos, wsno)
        of "while": initToken(lex, move(lex.strbuf), tkKeywordWhile, startLine, startCol, startPos, wsno)
        of "for": initToken(lex, move(lex.strbuf), tkKeywordFor, startLine, startCol, startPos, wsno)
        of "in": initToken(lex, move(lex.strbuf), tkKeywordIn, startLine, startCol, startPos, wsno)
        of "or": initToken(lex, move(lex.strbuf), tkOr, startLine, startCol, startPos, wsno)
        of "is": initToken(lex, move(lex.strbuf), tkKeywordIs, startLine, startCol, startPos, wsno)
        of "isnot": initToken(lex, move(lex.strbuf), tkKeywordIsnot, startLine, startCol, startPos, wsno)
        of "and": initToken(lex, move(lex.strbuf), tkAnd, startLine, startCol, startPos, wsno)
        of "not": initToken(lex, move(lex.strbuf), tkKeywordNot, startLine, startCol, startPos, wsno)
        of "of": initToken(lex, move(lex.strbuf), tkKeywordOf, startLine, startCol, startPos, wsno)
        of "case": initToken(lex, move(lex.strbuf), tkKeywordCase, startLine, startCol, startPos, wsno)
        of "break": initToken(lex, move(lex.strbuf), tkKeywordBreak, startLine, startCol, startPos, wsno)
        of "continue": initToken(lex, move(lex.strbuf), tkKeywordContinue, startLine, startCol, startPos, wsno)
        of "echo": initToken(lex, move(lex.strbuf), tkKeywordEcho, startLine, startCol, startPos, wsno)
        of "true": initToken(lex, move(lex.strbuf), tkKeywordTrue, startLine, startCol, startPos, wsno)
        of "false": initToken(lex, move(lex.strbuf), tkKeywordFalse, startLine, startCol, startPos, wsno)
        of "null": initToken(lex, move(lex.strbuf), tkKeywordNull, startLine, startCol, startPos, wsno)
        of "undefined": initToken(lex, move(lex.strbuf), tkKeywordUndefined, startLine, startCol, startPos, wsno)
        of "import": initToken(lex, move(lex.strbuf), tkKeywordImport, startLine, startCol, startPos, wsno)
        of "iterator":
          initToken(lex, move(lex.strbuf), tkKeywordIterator, startLine, startCol, startPos, wsno)
        of "mixin":
          initToken(lex, move(lex.strbuf), tkKeywordMixin, startLine, startCol, startPos, wsno)
        else: initToken(lex, move(lex.strbuf), tkIdentifier, startLine, startCol, startPos, wsno)
    else:
      lex.advance()
      result = initToken(lex, tkUnknown, startLine, startCol, startPos, wsno)  

proc getToken*(lex: var Lexer): TokenTuple =
  ## Returns the next token from the input
  result = nextToken(lex)