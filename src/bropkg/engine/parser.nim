# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

{.warning[ImplicitDefaultValue]:off.}

import pkg/[stashtable, jsony, flatty, flatty/hexprint,
           supersnappy, checksums/md5]
import std/[os, strutils, sequtils, sequtils,
            tables, json, memfiles, times, oids,
            macros]

import ./tokens, ./ast, ./css, ./memoization,
       ./logging, ./stdlib, ./properties

when compileOption("app", "console"):
  import pkg/kapsis/cli

# when not defined release:
  # import std/[jsonutils] 

export logging

type
  ParserType = enum
    Main
    Secondary 

  Warning* = tuple[msg: string, line, col: int]
  
  Stylesheets = StashTable[string, Stylesheet, 1000]
    # Where we'll store other Stylesheet instances
  Imports = OrderedTableRef[string, Node]

  Parser* = object
    lex: Lexer
    prev, curr, next: TokenTuple
    program: Stylesheet
    propsTable: PropertiesTable
    when compileOption("app", "console"):
      error: seq[Row]
      logger*: Logger
    else:
      error: string
    hasErrors*: bool
    when compileOption("app", "console"): 
      cacheEnabled*: bool
    warnings*: seq[Warning]
    currentSelector, lastParent: Node
    imports: Imports
      ## Nodes imported from other `Stylesheet` instances
    stylesheets: Stylesheets
      ## Other `Stylesheet` instances
    lib: StandardLibrary
    mCall: MCall
    mVar: MVar
    case ptype: ParserType
    of Main:
      directory: string
    else: discard
    path, filePath, cachePath: string

  PrefixFunction = proc(p: var Parser, scope: var seq[ScopeTable],
                        excludeOnly, includeOnly: set[TokenKind] = {},
                        returnType = ntVoid, isFunctionWrap = false): Node
  InfixFunction = proc(p: var Parser, left: Node, scope: var seq[ScopeTable]): Node
  ImportHandler = proc(th: (string, Stylesheets)) {.thread, nimcall, gcsafe.}

const
  tkVars = {tkVarCall, tkVarDef}
  tkUnits = {tkMM, tkCM, tkIN, tkPX, tkPT, tkPC, tkEM, tkEX, tkCH, tkREM, tkVW, tkVH, tkVMIN, tkVMAX} 
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
  tkAssignable = {tkString, tkInteger, tkBool, tkColor, tkAccQuoted} + tkVars + tkNamedColors
  tkComparable = tkAssignable
  tkAssignableFn = {tkJSON}
  tkTypedLiterals = {
    tkArrayLit, tkBoolLit, tkColorLit, tkFloatLit, tkFunctionLit,
    tkIntLit, tkObjectLit, tkSizeLit, tkStringLit
  }
  tkAssignableValue = {
    tkString, tkBool, tkFloat, tkInteger,
    tkIdentifier, tkVarCall, tkColor, tkAccQuoted
  } + tkNamedColors
  tkCompOperators = {tkEQ, tkNE, tkGT, tkGTE, tkLT, tkLTE}
  tkMathOperators = {tkPlus, tkMinus, tkMultiply, tkDivide}
  tkConditional = {tkIf, tkElif, tkElse}
  # tkNativeFn = {
  #   tkCSSCalc
  # }

proc hasWarnings*(p: Parser): bool =
  result = p.logger.warnLogs.len != 0

proc getStylesheet*(p: Parser): Stylesheet = p.program

#
# Forward declaration
#
proc getPrefixFn(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}): PrefixFunction
proc getInfixFn(p: var Parser): InfixFunction

proc parseRoot(p: var Parser, scope: var seq[ScopeTable], excludeOnly, includeOnly: set[TokenKind] = {}): Node
proc parsePrefix(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {},
          scope: var seq[ScopeTable], returnType = ntVoid, isFunctionWrap = false): Node

proc parseInfix(p: var Parser, left: Node, scope: var seq[ScopeTable]): Node

proc parseStatement(p: var Parser, parent: (TokenTuple, Node), scope: var seq[ScopeTable],
          excludeOnly, includeOnly: set[TokenKind] = {},
          returnType = ntVoid, isFunctionWrap, skipInitScope = false): Node

proc parseSelectorStmt(p: var Parser, parent: (TokenTuple, Node), scope: var seq[ScopeTable],
          excludeOnly, includeOnly: set[TokenKind] = {},
          returnType = ntVoid, isFunctionWrap = false)

proc parseCallCommand(p: var Parser, scope: var seq[ScopeTable],
          excludeOnly, includeOnly: set[TokenKind] = {},
          returnType = ntVoid, isFunctionWrap = false): Node

proc parseCallFnCommand(p: var Parser, scope: var seq[ScopeTable],
          excludeOnly, includeOnly: set[TokenKind] = {},
          returnType = ntVoid, isFunctionWrap = false): Node

proc getPrefixOrInfix(p: var Parser, scope: var seq[ScopeTable], includeOnly, excludeOnly: set[TokenKind] = {}): Node
proc importModule(th: (string, Stylesheets)) {.thread.}
proc importModuleCSS(th: (string, Stylesheets)) {.thread.}
proc parseVarCall(p: var Parser, tk: TokenTuple, varName: string, scope: var seq[ScopeTable]): Node

#
# Parse utils
#
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
        nnkVarTy.newTree(nnkBracketExpr.newTree(ident("seq"), ident("ScopeTable"))),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident("excludeOnly"),
        ident("includeOnly"),
        nnkBracketExpr.newTree(ident("set"), ident("TokenKind")),
        newNimNode(nnkCurly)
      ),
      nnkIdentDefs.newTree(ident("returnType"), newEmptyNode(), ident("ntVoid")),
      nnkIdentDefs.newTree(ident("isFunctionWrap"), newEmptyNode(), ident("false"))
    ],
    body
  )

proc globalScope(p: var Parser, node: Node) =
  ## Add `node` to global scope
  case node.nt:
  of ntFunction:
    p.program.stack[node.fnIdent] = node
  of ntVariable:
    p.program.stack[node.varName] = node
  else: discard

proc localScope(scope: ScopeTable, node: Node) =
  ## Add `node` to current `scope`
  case node.nt:
  of ntFunction:
    scope[node.fnIdent] = node
  of ntVariable:
    scope[node.varName] = node
  else: discard

proc stack(p: var Parser, node: Node, scope: var seq[ScopeTable]) =
  ## Stack `node` into local/global scope
  if scope.len == 1:
    localScope(scope[0], node)
  else:
    localScope(scope[^1], node)

proc getScope(p: var Parser, name: string, scopetables: var seq[ScopeTable]): tuple[st: ScopeTable, index: int] =
  ## Search through available `scopetables` and return
  ## the `ScopeTable` followed by `index`
  if scopetables.len > 0:
    for i in countdown(scopetables.high, scopetables.low):
      if scopetables[i].hasKey(name):
        return (scopetables[i], i)
  if p.program.stack.hasKey(name):
    return (p.program.stack, 0)

proc inScope(p: var Parser, name: string, scopetables: var seq[ScopeTable]): bool =
  result = p.getScope(name, scopetables).st != nil

proc use(node: Node) =
  ## Mark a callable (function or variable) as used
  case node.nt:
  of ntVariable:
    node.varUsed = true
  of ntFunction:
    node.fnUsed = true 
  of ntCall:
    if node.callNode.nt == ntVariable:
      node.callNode.varUsed = true
  else: discard

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

proc isFnCall(p: var Parser): bool =
  p.next.kind == tkLPAR and p.next.line == p.curr.line

proc toUnits(kind: TokenKind): Units =
  case kind:
  of tkPX: PX
  of tkEM: EM
  of tkPT: PT
  of tkVW: VW
  of tkVH: VH
  of tkMM: MM
  of tkCM: CM
  of tkIN: IN
  of tkPC: PC
  of tkEX: EX
  of tkCH: CH
  of tkREM: REM
  of tkVMIN: VMIN
  else: VMAX

template checkColon() =
  if p.curr is tkColon: walk p
  else: error(badIndentation, p.curr)

#
# Parse Literals
#
include handlers/pLiteral

newPrefixProc "parseComment":
  result = newComment("")
  walk p

proc getAssignableNode(p: var Parser, scope: var seq[ScopeTable]): Node =
  case p.curr.kind:
  of tkColor, tkNamedColors:
    result = newColor(p.curr.value)
    walk p
  of tkString:
    result = newString(p.curr.value)
    walk p
  of tkInteger:
    result = newInt(p.curr.value)
    walk p
  of tkBool:
    result = newBool(p.curr.value)
    walk p
  of tkVarCall:
    result = p.parseCallCommand(scope)
  of tkIdentifier:
    if p.isFnCall():
      return p.parseCallFnCommand(scope)
    result = nil
  else:
    if p.curr.isColor:
      result = newColor(p.curr.value)
      walk p

# Variable Declaration & Assignments
include handlers/[pImport, pExtend, pAssignment, pCond,
                  pFor, pCommand, pFunction, pSelector, pThis]

newPrefixProc "parseDotExpr":
  # if unlikely(p.prev is tkVarCall and p.prev.line == p.curr.line):
  #   echo "ntDotExpr"
  #   return
  walk p
  p.curr.kind = tkClass
  p.curr.value = "." & p.curr.value
  return p.parseClass(scope, excludeOnly, includeOnly)

# Prefix or Infix
proc getPrefixOrInfix(p: var Parser, scope: var seq[ScopeTable], includeOnly, excludeOnly: set[TokenKind] = {}): Node =
  let lht = p.parsePrefix(excludeOnly, includeOnly, scope)
  if p.curr.isInfix:
    if likely(lht != nil):
      let infix = p.parseInfix(lht, scope)
      if likely(infix != nil):
        return infix
    else: return
  result = lht

#
# Infix Comp
#
proc parseCompOp(p: var Parser, left: Node, scope: var seq[ScopeTable]): Node =
  walk p # op
  case p.curr.kind
  of tkInteger:
    result = p.parseInt(scope)
  of tkFloat:
    result = p.parseFloat(scope)
  of tkString:
    if p.prev.kind in {tkEQ, tkNE}:
      return p.parseString(scope)
    errorWithArgs(InvalidInfixOperator, p.curr, [p.prev.getOpStr, "String"])
  of tkVarCall:
    result = p.parseCallCommand(scope)
  of tkVarTyped:
    p.curr.kind = tkVarCall
    result = p.parseCallCommand(scope)
  of tkBool:
    if p.prev.kind in {tkEQ, tkNE}:
      return p.parseBool(scope)
    errorWithArgs(InvalidInfixOperator, p.curr, [p.prev.getOpStr, "Bool"])
  of tkIdentifier:
    if p.isFnCall():
      return p.parseCallFnCommand(scope)
    errorWithArgs(InvalidInfixOperator, p.curr, [p.prev.getOpStr])
  of tkColor, tkNamedColors:
    result = p.parseColor(scope)
  else: discard

proc parseMathOp(p: var Parser, left: Node, scope: var seq[ScopeTable]): Node =
  walk p
  result = p.getPrefixOrInfix(includeOnly = {tkInteger, tkFloat, tkVarCall, tkIdentifier, tkFnCall}, scope = scope)

proc getInfixFn(p: var Parser): InfixFunction =
  case p.curr.kind
  of tkCompOperators: parseCompOp
  of tkMathOperators: parseMathOp
  else: nil

proc parseInfix(p: var Parser, left: Node, scope: var seq[ScopeTable]): Node =
  var infixNode: Node # ntInfix
  let infixFn = p.getInfixFn()
  if infixFn != nil:
    let op = getInfixOp(p.curr.kind, false)
    if op != None:
      infixNode = newInfix(left)
      infixNode.infixOp = op
      let node = p.infixFn(infixNode.infixLeft, scope)
      if node != nil:
        infixNode.infixRight = node
      return infixNode
    var opMath = getInfixCalcOp(p.curr.kind, false)
    if likely(opMath != invalidCalcOp):
      infixNode = newInfixCalc(left)
      infixNode.mathInfixOp = opMath
      var node = p.infixFn(infixNode.mathLeft, scope)
      if likely(node != nil):
        infixNode.mathRight = node
        if infixNode.mathLeft.nt == ntInt and infixNode.mathRight.nt == ntInt:
          infixNode.mathResultType = ntInt
        else:
          infixNode.mathResultType = ntFloat
        return infixNode

#
# Statement List
#
proc parseStatement(p: var Parser, parent: (TokenTuple, Node), scope: var seq[ScopeTable],
                    excludeOnly, includeOnly: set[TokenKind] = {},
                    returnType = ntVoid, isFunctionWrap, skipInitScope = false): Node =
  if p.lastParent == nil:
    p.lastParent = parent[1]
  if p.curr isnot tkEOF:
    result = newStmt()
    if likely(skipInitScope == false):
      result.stmtScope = ScopeTable()
      scope.add(result.stmtScope)
    else:
      # already initialized at handler level (for example in `parseFn`)
      result.stmtScope = scope[^1]
    var tk = p.curr
    while p.curr isnot tkEOF and (p.curr.line > parent[0].line and p.curr.pos > parent[0].pos):
      tk = p.curr
      let node = p.parsePrefix(excludeOnly, includeOnly, scope, returnType, isFunctionWrap)
      if node != nil and not p.hasErrors:
        case node.nt
        of ntReturn:
          if unlikely(node.returnStmt.nt != returnType):
            case node.returnStmt.nt:
            of ntCallStack:
              if unlikely(node.returnStmt.stackReturnType != returnType):
                errorWithArgs(fnReturnTypeMismatch, tk, [$(node.returnStmt.stackReturnType), $(returnType)])  
              else: discard
            of ntMathStmt:
              if unlikely(node.returnStmt.mathResultType != returnType):
                errorWithArgs(fnReturnTypeMismatch, tk, [$(node.returnStmt.stackReturnType), $(returnType)])  
              else: discard
            of ntInfix: discard
            else:
              if likely(node.returnStmt.nt == ntCall):
                let fnReturnType = node.returnStmt.getNodeType()
                if unlikely(fnReturnType != returnType):
                  errorWithArgs(fnReturnTypeMismatch, tk, [$(fnReturnType), $(returnType)])  
              else:
                errorWithArgs(fnReturnTypeMismatch, tk, [$(node.returnStmt.nt), $(returnType)])  
        of ntFunction:
          result.trace(node.fnIdent)
        of ntVariable:
          result.trace(node.varName)
        else: discard
        add result.stmtList, node
      else: return nil
      p.lastParent = nil
    if result.stmtList.len == 0:
      return nil # Nestab

proc parseSelectorStmt(p: var Parser, parent: (TokenTuple, Node),
        scope: var seq[ScopeTable], excludeOnly, includeOnly: set[TokenKind] = {},
        returnType = ntVoid, isFunctionWrap = false) =
  if p.curr isnot tkEOF:
    while p.curr.kind != tkEOF and (p.curr.line > parent[0].line and p.curr.pos > parent[0].pos):
      let curr = p.curr
      let node = p.parsePrefix(excludeOnly, includeOnly, scope, returnType, isFunctionWrap)
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
        of ntExtend: discard
        of ntCall:
          parent[1].innerNodes[$node.callOid] = node
        of ntCallStack:
          if node.stackReturnType in {ntProperty, ntTagSelector, ntClassSelector,
                                      ntPseudoSelector, ntIDSelector}:
            # todo implement types for CSS selectors, example 
            parent[1].innerNodes[$node.stackOid] = node
          else: error(invalidCallContext, p.prev)
        of ntClassSelector, ntIDSelector, ntPseudoSelector:
          if likely(parent[1].innerNodes.hasKey(node.ident) == false):
            parent[1].innerNodes[node.ident] = node
          else:
            for k, v in node.innerNodes:
              parent[1].innerNodes[node.ident].innerNodes[k] = v
        else: errorWithArgs(unexpectedToken, curr, [curr.value])
      else: return
    p.lastParent = nil

#
# Prefix Statements
#
proc getPrefixFn(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}): PrefixFunction =
  if excludeOnly.len > 0:
    if p.curr in excludeOnly:
      errorWithArgs(InvalidContext, p.curr, [p.curr.value])
  if includeOnly.len > 0:
    if p.curr notin includeOnly:
      errorWithArgs(InvalidContext, p.curr, [p.curr.value])
  case p.curr.kind
  of tkIdentifier:
    if p.isFnCall():
      parseCallFnCommand
    elif tkIdentifier notin excludeOnly and tkFnCall notin includeOnly:
      parseProperty
    else: nil
  of tkInteger: parseInt
  of tkColor:   parseColor
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
  of tkThis:    parseThis
  of tkAccQuoted:   parseAccQuoted
  of tkNamedColors: parseNamedColor
  # of tkAssert:  parseAssert
  else:
    if p.next isnot tkColon:
      parseSelectorTag
    else:
      nil

proc parsePrefix(p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {},
            scope: var seq[ScopeTable], returnType = ntVoid, isFunctionWrap = false): Node =
  let prefixFn = p.getPrefixFn(excludeOnly, includeOnly)
  if likely(prefixFn != nil):
    return p.prefixFn(scope, excludeOnly, includeOnly, returnType, isFunctionWrap)
  result = nil

proc parseRoot(p: var Parser, scope: var seq[ScopeTable], excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  # Parse nodes at root-level
  result =
    case p.curr.kind:
    of tkVarDef:  p.parseAssignment(scope)
    of tkVarCall: p.parseCallCommand(scope)
    of tkFnDef:   p.parseFn(scope)
    of tkDotExpr: p.parseDotExpr(scope, excludeOnly, includeOnly)
    of tkID:      p.parseSelectorID(scope, excludeOnly, includeOnly)
    of tkComment: p.parseComment(scope)
    of tkIf:      p.parseCond(scope, excludeOnly, includeOnly)
    of tkCase:    p.parseCase(scope, excludeOnly, includeOnly)
    of tkEcho:    p.parseEchoCommand(scope)
    of tkFor:     p.parseFor(scope, excludeOnly, includeOnly)
    of tkImport:  p.parseImport(scope, excludeOnly, includeOnly)
    of tkIdentifier:
      if p.next.kind == tkLPAR and p.next.line == p.curr.line:
        p.parseCallFnCommand(scope, excludeOnly, includeOnly)
      else: p.parseSelectorTag(scope, excludeOnly, includeOnly)
    else: nil
  if result == nil and not p.hasErrors:
    let tk = if p.curr isnot tkEOF: p.curr else: p.prev
    errorWithArgs(unexpectedToken, tk, [tk.value])


template startParseStylesheet(src: string, scope: var seq[ScopeTable]) =
  when defined wasm:
    p.lex = tokens.newLexer(src) # read from string
    p.logger = Logger(filePath: "")
  else:
    p.lex = tokens.newLexer(readFile(src))
    p.logger = Logger(filePath: src)
    p.stylesheets = newStashTable[string, Stylesheet, 1000]()
  p.imports = Imports()
  p.propsTable = initPropsTable()
  p.lib = StandardLibrary()
  scope.add(ScopeTable())
  p.program = Stylesheet(stack: scope[0])
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  while p.curr isnot tkEOF:
    if p.lex.hasError:
      echo "Lexer errors:"
      echo p.lex.getError # todo bring lexer errors to the current logger instance
      break
    elif p.hasErrors: break
    let node = p.parseRoot(scope, excludeOnly = {tkExtend, tkPseudo, tkReturn})
    if likely(node != nil):
      add p.program.nodes, node
    else: break
  p.lex.close()

proc importModule(th: (string, Stylesheets)) {.thread.} =
  {.gcsafe.}:
    proc newImporter(): Parser =
      var p = Parser(ptype: Secondary, filePath: th[0])
      var scope = newSeq[ScopeTable]()
      startParseStylesheet(th[0], scope)
      result = p
    var subParser = newImporter()
    if subParser.hasErrors:
      for error in subParser.logger.errors:
        display(error)
      display(" 👉 " & subParser.logger.filePath)
      return
    th[1].withValue(th[0]):
      value[] = subParser.getStylesheet

proc importModuleCSS(th: (string, Stylesheets)) {.thread.} =
  {.gcsafe.}:
    let cssParser = parseCSS(readFile(th[0]))
    if not cssParser.status:
      display(cssParser.msg)
      display(" 👉 " & th[0])
      return
    th[1].withValue(th[0]):
      value[] = cssParser.stylesheet

proc parseStylesheet*(src: string, enableCache = false): Parser =
  var p = Parser(ptype: Main)
  when not defined wasm:
    p.filePath = src 
    p.directory = src.parentDir()
    p.path = src.parentDir()
  when compileOption("app", "console"): 
    p.cacheEnabled = enableCache
  var scope = newSeq[ScopeTable]()
  startParseStylesheet(src, scope)
  for k, v in p.program.stack:
    # check for unused variables/functions
    case v.nt:
    of ntVariable:
      if unlikely(v.varUsed == false):
        p.logger.warn(declaredNotUsed, v.varMeta.line, v.varMeta.pos, true, k)
    of ntFunction:
      if unlikely(v.fnUsed == false):
        p.logger.warn(declaredNotUsed, v.fnMeta.line, v.fnMeta.pos, true, v.fnName)
    else: discard
  result = p
