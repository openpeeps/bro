# Bro aka NimSass
# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro

import std/[colors]
import toktok

export lexbase.close

static:
  Program.settings(true, "TK")

handlers:

  proc handleClassSelector(lex: var Lexer, kind: TokenKind) =
    ready lex
    inc lex
    while true:
      if lex.hasLetters(lex.bufpos) or lex.hasNumbers(lex.bufpos):
        add lex
      else:
        break
    lex.kind = TKClass 

  proc handleHash(lex: var Lexer, kind: TokenKind) =
    ready lex
    inc lex
    while true:
      if lex.hasLetters(lex.bufpos) or lex.hasNumbers(lex.bufpos):
        add lex
      else: break
    if isColor("#" & lex.token):
      lex.token = "#" & lex.token
      lex.kind = TKColor
    else:
      lex.kind = TkID 

  proc handleVariable(lex: var Lexer, kind: TokenKind) =
    ready lex
    inc lex
    while true:
      if lex.hasLetters(lex.bufpos) or lex.hasNumbers(lex.bufpos):
        add lex
      else:
        break
    if lex.buf[lex.bufpos] == ':':
      lex.kind = TKVariable
    else:
      lex.kind = TKVariableCall

  proc handleCurlyVar(lex: var Lexer, kind: TokenKind) =
    ready lex
    inc lex
    lex.handleVariable(kind)
    if token(lex) == '}':
      inc lex
      lex.kind = TKVarConcat
    else:
      lex.setError("Missing closing curly bracket")

  proc handleExclamation(lex: var Lexer, kind: TokenKind) =
    ready lex
    inc lex
    while true:
      if lex.hasLetters(lex.bufpos) or lex.hasNumbers(lex.bufpos):
        add lex
      else:
        if lex.buf[lex.bufpos] == '=':
          add lex
          lex.kind = TKNE
          return
        break
    if lex.token == "important":
      lex.kind = TKImportant
    elif lex.token == "default":
      lex.kind = TKDefault
    else: discard # TODO error

  proc handleSnippets*(lex: var Lexer, kind: TokenKind) =    
    lex.startPos = lex.getColNumber(lex.bufpos)
    var k = TKPreview
    if lex.next("``html"):
      setLen(lex.token, 0)
      inc lex, 7
      skip lex
    else:
      lex.setError("Unknown markup. Use either `html` or `timl`")
      return
    while true:
      case token lex:
      of '`':
        if lex.next("``"):
          lex.kind = k
          inc lex, 3
          return
        else:
          add lex
      of EndOfFile:
        lex.setError("EOF reached before end of snippet")
        return
      else:
        add lex
      skip lex
      lex.startPos = lex.getColNumber(lex.bufpos)

  proc handleAnd(lex: var Lexer, kind: TokenKind) =
    ready lex
    add lex
    if token(lex) == ':':
      lex.kind = TKPseudoClass
      add lex
    elif token(lex) == '&':
      lex.kind = TKAndAnd
      add lex
    else:
      lex.kind = kind

tokens:
  A            > "a"
  Abbr         > "abbr"
  Acronym      > "acronym"
  Address      > "address"
  Applet       > "applet"
  Area         > "area"
  Article      > "article"
  Aside        > "aside"
  Audio        > "audio"
  Bold         > "b"
  Base         > "base"
  Basefont     > "basefont"
  Bdi          > "bdi"
  Bdo          > "bdo"
  Big          > "big"
  Blockquote   > "blockquote"
  Body         > "body"
  Br           > "br"
  Button       > "button"
  Canvas       > "canvas"
  Caption      > "caption"
  Center       > "center"
  Cite         > "cite"
  Code         > "code"
  Col          > "col"
  Colgroup     > "colgroup"
  Data         > "data"
  Datalist     > "datalist"
  DD           > "dd"
  Del          > "del"
  Details      > "details"
  DFN          > "dfn"
  Dialog       > "dialog"
  Dir          > "dir"
  Div          > "div"
  Doctype      > "doctype"
  DL           > "dl"
  DT           > "dt"
  EM           > "em"
  Embed        > "embed"
  Fieldset     > "fieldset"
  Figcaption   > "figcaption"
  Figure       > "figure"
  Font         > "font"
  Footer       > "footer"
  Form         > "form"
  Frame        > "frame"
  Frameset     > "frameset"
  H1           > "h1"
  H2           > "h2"
  H3           > "h3"
  H4           > "h4"
  H5           > "h5"
  H6           > "h6"
  Head         > "head"
  Header       > "header"
  Hr           > "hr"
  Html         > "html"
  Italic       > "i"
  Iframe       > "iframe"
  Img          > "img"
  Input        > "input"
  Ins          > "ins"
  Kbd          > "kbd"
  Label        > "label"
  Legend       > "legend"
  Li           > "li"
  Link         > "link"
  Main         > "main"
  Map          > "map"
  Mark         > "mark"
  Meta         > "meta"
  Meter        > "meter"
  Nav          > "nav"
  Noframes     > "noframes"
  Noscript     > "noscript"
  Object       > "object"
  Ol           > "ol"
  Optgroup     > "optgroup"
  Option       > "option"
  Output       > "output"
  Paragraph    > "p"
  Param        > "param"
  Pre          > "pre"
  Progress     > "progress"
  Quotation    > "q"
  RP           > "rp"
  RT           > "rt"
  Ruby         > "ruby"
  Strike       > "s"
  Samp         > "samp"
  Script       > "script"
  Section      > "section"
  Select       > "select"
  Small        > "small"
  Source       > "source"
  Span         > "span"
  Strike_Long  > "strike"
  Strong       > "strong"
  Style        > "style"
  Sub          > "sub"
  Summary      > "summary"
  Sup          > "sup"
  SVG          > "svg"
  Table        > "table"
  Tbody        > "tbody"
  TD           > "td"
  Template     > "template"
  Textarea     > "textarea"
  Tfoot        > "tfoot"
  TH           > "th"
  Thead        > "thead"
  Time         > "time"
  Title        > "title"
  TR           > "tr"
  Track        > "track"
  TT           > "tt"
  Underline    > "u"  
  UL           > "ul"
  Var          > "var"
  Video        > "video"
  WBR          > "wbr"
  Root         > "root"

  stdStartsWith  > "startsWith"
  stdEndsWith    > "endsWith"
  stdCount       > "count"
  stdLowercase   > "lowercase"
  stdUppercase   > "uppercase"

  AltAnd      > "and"
  AltOr       > "or"
  Colon       > ':'
  Comma       > ','
  And         > tokenize(handleAnd, '&')
  AndAnd        # && handleAnd
  PseudoClass   # &: handleAnd
  Pipe        > '|':
    OR        ? '|'   # ||
  Multi       > '*'
  Minus       > '-'
  Plus        > '+'
  Assign    > '=':
    EQ      ? '='   # ==
  NE        # != handledExclamation
  GT        > '>':
    GTE     ? '='
  LT        > '<':
    LTE     ? '='
  QMark     > '?'
  LPar      > '('
  RPar      > ')'
  LB        > '['
  RB        > ']'
  VarConcat > tokenize(handleCurlyVar, '{')
  LC        # '{'
  RC        # '}'
  ExcRule     > tokenize(handleExclamation, '!')
  Hash        > tokenize(handleHash, '#')
  Variable    > tokenize(handleVariable, '$')
  VariableCall
  Class       > tokenize(handleClassSelector, '.')
  Divide      > '/':
    Comment   > '/' .. EOL
  AtRule      > '@':
    Import    > "import"
    Extend    > "extend"
    Use       > "use"
    Mixin     > "mixin"
  ID
  Color
  Important
  Default
  Preview     > tokenize(handleSnippets, '`')
  FunctionCall
  FunctionStmt
  If          > "if"
  Elif        > "elif"
  Else        > "else"
  For         > "for"
  In          > "in"
  When        > "when"
  Bool        > {"true", "false"}