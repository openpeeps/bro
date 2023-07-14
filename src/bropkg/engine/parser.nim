# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import pkg/stashtable
import std/[os, strutils, critbits, sequtils, hashes,
          tables, json, memfiles, times, oids, macros]
import ./tokens, ./ast, ./logging, ./stdlib, ./properties, ./memo

when compileOption("app", "console"):
  import pkg/kapsis/cli

when not defined release:
  import std/[jsonutils] 

export logging

type
  ParserType = enum
    Main
    Secondary 

  Warning* = tuple[msg: string, line, col: int]
  
  Stylesheets = StashTable[string, Program, 1000]
    # Where we'll store other Stylesheet instances
  Imports = OrderedTableRef[string, Node]

  Parser* = object
    lex: Lexer
    prev, curr, next: TokenTuple
    program: Program
    propsTable: PropertiesTable
    when compileOption("app", "console"):
      error: seq[Row]
      logger*: Logger
    else:
      error: string
    hasErrors*: bool
    warnings*: seq[Warning]
    currentSelector, lastParent: Node
    imports: Imports
      ## Nodes imported from other `Stylesheet` instances
    stylesheets: Stylesheets
      ## Other `Stylesheet` instances
    lib: StandardLibrary
    case ptype: ParserType
    of Main:
      directory: string
    else: discard
    path, filePath, cachePath: string

  PrefixFunction = proc(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node
  InfixFunction = proc(p: var Parser, left: Node, scope: ScopeTable = nil): Node

const
  tkVars = {tkVarCall, tkVarDef}
  tkNamedColors = {
    tkColorAliceblue, tkColorAntiquewhite, tkColorAqua, tkColorAquamarine, tkColorAzure,
    tkColorBeige, tkColorBisque, tkColorBlack, tkColorBlanchedalmond, tkColorBlue, tkColorBlueviolet,
    tkColorBrown, tkColorBurlywood, tkColorCadetblue, tkColorChartreuse, tkColorChocolate, tkColorCoral,
    tkColorCornflowerblue, tkColorCornsilk, tkColorCrimson, tkColorCyan, tkColorDarkblue, tkColorDarkcyan,
    tkColorDarkgoldenrod, tkColorDarkgray, tkColorDarkgreen, tkColorDarkkhaki, tkColorDarkmagenta, tkColorDarkolivegreen,
    tkColorDarkorange, tkColorDarkorchid, tkColorDarkred, tkColorDarksalmon, tkColorDarkseagreen, tkColorDarkslateblue,
    tkColorDarkslategray, tkColorDarkturquoise, tkColorDarkviolet, tkColorDeeppink, tkColorDeepskyblue, tkColorDimgray,
    tkColorDodgerblue, tkColorFirebrick, tkColorFloralwhite, tkColorForestgreen, tkColorFuchsia, tkColorGainsboro,
    tkColorGhostwhite, tkColorGold, tkColorGoldenrod, tkColorGray, tkColorGrey, tkColorGreen, tkColorGreenyellow,
    tkColorHoneydew, tkColorHotpink, tkColorIndianred, tkColorIndigo, tkColorIvory, tkColorKhaki, tkColorLavender,
    tkColorLavenderblush, tkColorLawngreen, tkColorLemonchiffon, tkColorLightblue, tkColorLightcoral, tkColorLightcyan,
    tkColorLightgoldenrodyellow, tkColorLightgray, tkColorLightgreen, tkColorLightpink, tkColorLightsalmon,
    tkColorLightseagreen, tkColorLightskyblue, tkColorLightslategray, tkColorLightsteelblue, tkColorLightyellow,
    tkColorLime, tkColorLimegreen, tkColorLinen, tkColorMagenta, tkColorMaroon, tkColorMediumaquamarine, tkColorMediumblue,
    tkColorMediumorchid, tkColorMediumpurple, tkColorMediumseagreen, tkColorMediumslateblue, tkColorMediumspringgreen,
    tkColorMediumturquoise, tkColorMediumvioletred, tkColorMidnightblue, tkColorMintcream, tkColorMistyrose,
    tkColorMoccasin, tkColorNavajowhite, tkColorNavy, tkColorOldlace, tkColorOlive, tkColorOlivedrab, tkColorOrange,
    tkColorOrangered, tkColorOrchid, tkColorPalegoldenrod, tkColorPalegreen, tkColorPaleturquoise, tkColorPalevioletred,
    tkColorPapayawhip, tkColorPeachpuff, tkColorPeru, tkColorPink, tkColorPlum, tkColorPowderblue, tkColorPurple,
    tkColorRebeccapurple, tkColorRed, tkColorRosybrown, tkColorRoyalblue, tkColorSaddlebrown, tkColorSalmon,
    tkColorSandybrown, tkColorSeagreen, tkColorSeashell, tkColorSienna, tkColorSilver, tkColorSkyblue, tkColorSlateblue,
    tkColorSlategray, tkColorSnow, tkColorSpringgreen, tkColorSteelblue, tkColorTan, tkColorTeal, tkColorThistle,
    tkColorTomato, tkColorTurquoise, tkColorViolet, tkColorWheat, tkColorWhite, tkColorWhitesmoke, tkColorYellow, tkColorYellowgreen
  }
  # tkHtmlTags = {
  #   tkA, tkAbbr, tkAcronym, tkAddress, tkApplet, tkArea, tkArticle, tkAside,
  #   tkAudio, tkBold, tkBase, tkBasefont, tkBdi, tkBdo, tkBig, tkBlockquote, tkBody,
  #   tkBr, tkButton, tkCanvas, tkCaption, tkCenter, tkCite, tkCode, tkCol, tkColgroup,
  #   tkData, tkDatalist, tkDd, tkDel, tkDetails, tkDfn, tkDialog, tkDir, tkDiv,
  #   tkDoctype, tkDl, tkDt, tkEm, tkEmbed, tkFieldset, tkFigcaption, tkFigure, tkFont,
  #   tkFooter, tkForm, tkFrame, tkFrameset, tkH1, tkH2, tkH3, tkH4, tkH5, tkH6, tkHead,
  #   tkHeader, tkHr, tkHtml, tkItalic, tkIframe, tkImg, tkInput, tkIns, tkKbd, tkLabel, tkLegend,
  #   tkLi, tkLink, tkMain, tkMap, tkMark, tkMeta, tkMeter, tkNav, tkNoframes, tkNoscript,
  #   tkObject, tkOl, tkOptgroup, tkOption, tkOutput, tkParagraph, tkParam, tkPre, tkProgress, tkQuotation,
  #   tkRp, tkRt, tkRuby, tkStrike, tkSamp, tkScript, tkSection, tkSelect, tkSmall, tkSource, tkSpan,
  #   tkStrikeLong, tkStrong, tkStyle, tkSub, tkSummary, tkSup, tkSvg, tkTable, tkTbody, tkTd,
  #   tkTemplate, tkTextarea, tkTfoot, tkTh, tkThead, tkTime, tkTitle, tkTr, tkTrack, tkTt,
  #   tkUnderline, tkUl, tkVideo, tkWbr, tkRoot
  # }
  tkAssignable = {tkString, tkInteger, tkBool, tkColor} + tkVars + tkNamedColors
  tkComparable = tkAssignable
  tkAssignableFn = {tkJSON}
  tkTypedLiterals = {
    tkArrayLit, tkBoolLit, tkColorLit, tkFloatLit, tkFunctionLit,
    tkIntLit, tkObjectLit, tkSizeLit, tkStringLit
  }
  tkAssignableValue = {
    tkString, tkBool, tkFloat, tkInteger,
    tkIdentifier, tkVarCall, tkColor
  } + tkNamedColors
  tkCompOperators = {tkEQ, tkNE, tkGT, tkGTE, tkLT, tkLTE}
  tkMathOperators = {tkPlus, tkMinus, tkMultiply, tkDivide}
  tkConditional = {tkIf, tkElif, tkElse}
  # tkNativeFn = {
  #   tkCSSCalc
  # }

when compileOption("app", "console"):
  template err(msg: string) =
    add p.error, @[span("Error ($2:$3): $1" % [msg, $p.curr.line, $p.curr.col])]

  template err(msg: string, tk: TokenTuple, sfmt: varargs[string]) =
    var newRow: Row
    add newRow, span("Error", fgRed, indentSize = 0)
    add newRow, span("(" & $(tk.line) & ":" & $(tk.col) & ")")
    add newRow, span(msg)
    for str in sfmt:
      add newRow, span(str, fgMagenta)
    add p.error, newRow
    add p.error, @[span(p.filePath)]
    return

  proc getError*(p: Parser): seq[Row] =
    result =
      if p.error.len != 0: p.error
      else:
        @[@[span(p.lex.getError)]]

else:
  template err(msg: string) =
    p.error = "Error ($2:$3): $1" % [msg, $(p.curr.line), $(tk.col)]

  template err(msg: string, tk: TokenTuple, sfmt: varargs[string]) =
    var errmsg = msg
    for str in sfmt:
      add errmsg, indent("\"" & str & "\"", 1)  
    p.error = "Error ($2:$3): $1" % [errmsg, $(tk.line), $(tk.col)]
    return

  proc getError*(p: Parser): string =
    result =
      if p.error.len != 0: p.error
      else: p.lex.getError

proc hasError*(p: Parser): bool =
  result = p.error.len != 0 or p.lex.hasError

proc hasWarnings*(p: Parser): bool =
  result = p.logger.warnLogs.len != 0

proc getProgram*(p: Parser): Program = p.program

#
# Forward declaration
#
proc getPrefixFn(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}): PrefixFunction
proc getInfixFn(p: var Parser): InfixFunction

proc parseRoot(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}): Node
proc parsePrefix(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}, scope: ScopeTable = nil): Node
proc parseInfix(p: var Parser, left: Node): Node

proc parseStatement(p: var Parser, parent: (TokenTuple, Node), scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node
proc parseSelectorStmt(p: var Parser, parent: (TokenTuple, Node), scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {})

proc parseCallCommand(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node
proc parseCallFnCommand(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node
proc getPrefixOrInfix(p: var Parser, scope: ScopeTable, includeOnly, excludeOnly: set[TokenKind] = {}): Node
proc importThread(th: (string, Stylesheets)) {.thread.}

#
# Parse utils
#
when not defined release:
  proc `$`(node: Node): string = pretty(node.toJson(), 2)
  proc `$`(program: Program): string = pretty(program.toJson(), 2)

proc walk(p: var Parser, offset = 1) =
  var i = 0
  while offset > i:
    inc i
    p.prev = p.curr
    p.curr = p.next
    p.next = p.lex.getToken()

macro newPrefixProc(name: static string, body: untyped) =
  # Create a new prefix procedure with `name` and `body`
  ident(name).newProc(
    [
      ident("Node"), # return type
      nnkIdentDefs.newTree(
        ident("p"),
        nnkVarTy.newTree(ident("Parser")),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident("scope"),
        ident("ScopeTable"),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident("excludeOnly"),
        ident("includeOnly"),
        nnkBracketExpr.newTree(ident("set"), ident("TokenKind")),
        newNimNode(nnkCurly)
      )
    ],
    body
  )

proc getLiteralType(p: var Parser): NodeType =
  result =
    case p.curr.kind:
    of tkArrayLit: ntArray
    of tkBoolLit: ntBool
    of tkColorLit: ntColor
    of tkFloatLit: ntFloat
    of tkFunctionLit: ntFunction
    of tkIntLit: ntInt
    of tkObjectLit: ntObject
    of tkSizeLit: ntSize
    of tkStringLit: ntString
    else: ntVoid

proc getOpStr(tk: TokenTuple): string =
  result =
    case tk.kind:
      of tkEQ: "=="
      of tkNE: "!="
      of tkLT: "<"
      of tkLTE: "<="
      of tkGT: ">"
      of tkGTE: ">="
      else: ""

proc nextToken(p: var Parser, kind: TokenKind): bool = p.next.kind == kind
proc nextToken(p: var Parser, kind: set[TokenKind]): bool = p.next.kind in kind

proc isColor(tk: TokenTuple): bool {.inline.} =
  tk.kind in tkNamedColors

proc isChild(p: var Parser, tk: TokenTuple): bool {.inline.} =
  p.curr.pos > tk.pos and (p.curr.line > tk.line and p.curr.kind != tkEOF)

proc isInfix*(p: var Parser): bool {.inline.} =
  p.curr.kind in tkCompOperators + tkMathOperators 

proc isInfix*(tk: TokenTuple): bool {.inline.} =
  tk.kind in tkCompOperators + tkMathOperators 

proc `isnot`(tk: TokenTuple, kind: TokenKind): bool {.inline.} =
  tk.kind != kind

proc `is`(tk: TokenTuple, kind: TokenKind): bool {.inline.} =
  tk.kind == kind

proc `in`(tk: TokenTuple, kind: set[TokenKind]): bool {.inline.} =
  tk.kind in kind

proc `notin`(tk: TokenTuple, kind: set[TokenKind]): bool {.inline.} =
  tk.kind notin kind

template checkColon() =
  if p.curr is tkColon: walk p
  else: error(BadIndentation, p.curr)

#
# Parse Literals
#
include handlers/pLiteral

proc parseComment(p: var Parser, scope: ScopeTable, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  result = newComment("")
  walk p

proc getAssignableNode(p: var Parser, scope: ScopeTable = nil): Node =
  case p.curr.kind:
  of tkColor, tkNamedColors:
    result = newValue(p.curr.value.newColor)
    walk p
  of tkString:
    result = newValue(p.curr.value.newString)
    walk p
  of tkInteger:
    result = newValue(p.curr.value.newInt)
    walk p
  of tkBool:
    result = newValue(p.curr.value.newBool)
    walk p
  of tkVarCall:
    result = p.parseCallCommand(scope)
  else:
    if p.curr.isColor:
      result = newValue(p.curr.value.newColor)
      walk p

# Variable Declaration & Assignments
include handlers/[pImport, pExtend, pAssignment, pCond, pFor, pCommand, pFunction, pSelector]

proc parseDotExpr(p: var Parser, scope: ScopeTable, excludeOnly, includeOnly: set[TokenKind] = {}): Node = 
  if unlikely(p.prev is tkVarCall and p.prev.line == p.curr.line):
    echo "ntDotExpr"
    return
  walk p
  p.curr.kind = tkClass
  p.curr.value = "." & p.curr.value
  return p.parseClass(scope, excludeOnly, includeOnly)

# Prefix or Infix
proc getPrefixOrInfix(p: var Parser, scope: ScopeTable, includeOnly, excludeOnly: set[TokenKind] = {}): Node =
  if p.next.isInfix:
    let lht = p.parsePrefix(excludeOnly, includeOnly, scope)
    if lht != nil:
      let infix = p.parseInfix(lht)
      if infix != nil:
        return infix
    else: return
  return p.parsePrefix(excludeOnly, includeOnly, scope)

#
# Infix Comp
#
proc parseCompOp(p: var Parser, left: Node, scope: ScopeTable = nil): Node =
  walk p # op
  case p.curr.kind
  of tkInteger:
    result = p.parseInt()
  of tkFloat:
    result = p.parseFloat()
  of tkString:
    if p.prev.kind in {tkEQ, tkNE}:
      return p.parseString()
    errorWithArgs(InvalidInfixOperator, p.curr, [p.prev.getOpStr, "String"])
  of tkVarCall:
    echo "tkVarCall"
    echo p.curr
  of tkBool:
    if p.prev.kind in {tkEQ, tkNE}:
      return p.parseBool()
    errorWithArgs(InvalidInfixOperator, p.curr, [p.prev.getOpStr, "Bool"])
  of tkColor, tkNamedColors:
    result = p.parseColor(scope)
  else: discard

proc parseMathOp(p: var Parser, left: Node, scope: ScopeTable = nil): Node =
  case p.next.kind
  of tkInteger, tkFloat:
    walk p
  of tkVarCall:
    discard
  else: discard

proc getInfixFn(p: var Parser): InfixFunction =
  case p.curr.kind
  of tkCompOperators: parseCompOp
  of tkMathOperators: parseMathOp
  else: nil

proc parseInfix(p: var Parser, left: Node): Node =
  let infixFn = p.getInfixFn()
  if infixFn != nil:
    result = newInfix(left)
    result.infixOp = getInfixOp(p.curr.kind, false)
    let node = p.infixFn(result.infixLeft)
    if node != nil:
      result.infixRight = node

#
# Statement List
#
proc parseStatement(p: var Parser, parent: (TokenTuple, Node),
                    scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  var isFn: bool
  var returnType: NodeType
  if p.lastParent == nil:
    p.lastParent = parent[1]
    isFn = p.lastParent.nt == ntFunction
  if p.curr isnot tkEOF:
    result = newStmt()
    result.stmtScope = scope
    var tk = p.curr
    while p.curr isnot tkEOF and (p.curr.line > parent[0].line and p.curr.pos > parent[0].pos):
      tk = p.curr
      let node = p.parsePrefix(excludeOnly, includeOnly, result.stmtScope)
      if node != nil:
        case node.nt
        of ntReturn:
          if unlikely(p.lastParent.fnReturnType != node.returnStmt.nt):
            errorWithArgs(fnReturnTypeMismatch, tk,
              [p.lastParent.fnName, $(node.returnStmt.nt), $(p.lastParent.fnReturnType)])
          returnType = node.returnStmt.nt
        of ntVariable:
          result.trace(node.varName)
        else: discard
        add result.stmtList, node
      else: return nil
    if isFn:
      if p.lastParent.fnReturnType != returnType:
        errorWithArgs(fnReturnTypeMismatch, tk,
          [p.lastParent.fnName, $(returnType), $(p.lastParent.fnReturnType)])
    p.lastParent = nil
    if result.stmtList.len == 0:
      return nil # Nestab

proc parseSelectorStmt(p: var Parser, parent: (TokenTuple, Node),
        scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}) =
  if p.curr isnot tkEOF:
    while p.curr.kind != tkEOF and (p.curr.line > parent[0].line and p.curr.pos > parent[0].pos):
      let node = p.parsePrefix(excludeOnly, includeOnly, scope)
      if likely(node != nil):
        p.lastParent = parent[1]
        case node.nt:
        of ntProperty:
          parent[1].properties[node.pName] = node
        of ntForStmt:
          parent[1].innerNodes[$node.forOid] = node
        of ntCondStmt:
          parent[1].innerNodes[$node.condOid] = node
        of ntCaseStmt:
          parent[1].innerNodes[$node.caseOid] = node
        of ntExtend:
          discard
        else:
          if not parent[1].innerNodes.hasKey(node.ident):
            parent[1].innerNodes[node.ident] = node
          else:
            for k, v in node.innerNodes:
              parent[1].innerNodes[node.ident].innerNodes[k] = v
          # parent[1].innerNodes[node.ident] = node
      else: return
    p.lastParent = nil

#
# Prefix Statements
#
proc getPrefixFn(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}): PrefixFunction =
  if excludeOnly.len != 0:
    if p.curr in excludeOnly:
      errorWithArgs(InvalidContext, p.curr, [p.curr.value])
  if includeOnly.len != 0:
    if p.curr notin includeOnly:
      errorWithArgs(InvalidContext, p.curr, [p.curr.value])
  case p.curr.kind
    of tkIdentifier:
      if p.next.kind == tkLPAR and p.next.line == p.curr.line:
        parseCallFnCommand
      elif tkIdentifier notin excludeOnly:
        parseProperty
      else: nil
    of tkInteger: parseInt
    of tkString:  parseString
    of tkVarCall: parseCallCommand
    of tkVarDef:  parseAssignment
    of tkReturn:  parseReturnCommand
    of tkEcho:    parseEchoCommand
    of tkBool:    parseBool
    of tkLB:      parseAnoArray
    of tkLC:      parseAnoObject
    of tkCase:    parseCase
    of tkIf:      parseCond
    of tkFor:     parseFor
    of tkDotExpr: parseDotExpr
    of tkFnDef:   parseFn
    of tkComment: parseComment
    of tkExtend:  parseExtend
    else: nil

proc parsePrefix(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}, scope: ScopeTable = nil): Node =
  let prefixFn = p.getPrefixFn(excludeOnly, includeOnly)
  if prefixFn != nil:
    return p.prefixFn(scope)

proc parseRoot(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  # Parse nodes at root-level
  result = case p.curr.kind:
            of tkVarDef: p.parseAssignment(p.program.stack)
            of tkVarCall: p.parseCallCommand()
            of tkFnDef: p.parseFn(nil)
            of tkDotExpr: p.parseDotExpr(nil, excludeOnly, includeOnly)
            of tkComment: p.parseComment(nil)
            of tkIf: p.parseCond(nil, excludeOnly, includeOnly)
            of tkCase: p.parseCase(nil, excludeOnly, includeOnly)
            of tkEcho: p.parseEchoCommand(nil)
            of tkFor: p.parseFor(nil, excludeOnly, includeOnly)
            of tkImport: p.parseImport(nil, excludeOnly, includeOnly)
            of tkIdentifier:
              if p.next.kind == tkLPAR and p.next.line == p.curr.line:
                p.parseCallFnCommand()
              else: nil
            else: nil
  if result == nil and not p.hasErrors:
    let tk = if p.curr isnot tkEOF: p.curr else: p.prev
    errorWithArgs(UnexpectedToken, tk, [tk.value])

template startParseProgram(src: string, scope: ScopeTable) =
  when defined wasm:
    p.lex = Lexer.init(src) # read from string
    p.logger = Lexer.init(filePath: "")
  else:
    p.lex = Lexer.init(readFile(src))
    p.logger = Logger(filePath: src)
    p.stylesheets = newStashTable[string, Program, 1000]()
  p.imports = Imports()
  p.propsTable = initPropsTable()
  p.lib = StandardLibrary()
  p.program = Program(stack: scope)
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  # p.memtable = Memtable()
  while p.curr isnot tkEOF:
    if p.lex.hasError:
      echo "Lexer errors:"
      echo p.lex.getError # todo bring lexer errors to the current logger instance
      break
    elif p.hasErrors: break
    let node = p.parseRoot(excludeOnly = {tkExtend, tkPseudo, tkReturn})
    if likely(node != nil):
      add p.program.nodes, node
    else: break
  p.lex.close()

proc importThread(th: (string, Stylesheets)) {.thread.} =
  {.gcsafe.}:
    proc newImporter(): Parser =
      var p = Parser(ptype: Secondary, filePath: th[0])
      startParseProgram(th[0], ScopeTable())
      result = p
    var subParser = newImporter()
    if subParser.hasErrors:
      for error in subParser.logger.errors:
        display(error)
      display(" 👉 " & subParser.logger.filePath)
      return
    th[1].withValue(th[0]):
      value[] = subParser.getProgram

proc parseProgram*(src: string): Parser =
  var p = Parser(ptype: Main)
  when not defined wasm:
    p.filePath = src 
    p.directory = src.parentDir()
    p.path = src.parentDir()
  startParseProgram(src, ScopeTable())
  for k, v in p.program.stack:
    # check for unused variables/functions
    case v.nt:
    of ntVariable:
      if unlikely(v.varUsed == false):
        p.logger.warn(DeclaredNotUsed, v.varMeta.line, v.varMeta.pos, true, k)
    of ntFunction:
      if unlikely(v.fnUsed == false):
        p.logger.warn(DeclaredNotUsed, v.fnMeta.line, v.fnMeta.pos, true, v.fnName)
    else: discard
  result = p
