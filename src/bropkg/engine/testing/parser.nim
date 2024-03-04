# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

{.warning[ImplicitDefaultValue]: off.}

import
  pkg/[flatty, supersnappy, chroma, checksums/md5, malebolgia, malebolgia/ticketlocks]

import
  std/[os, strutils, sequtils, sequtils, tables, json, memfiles, times, oids, macros]

import ./tokens, ./ast, ./memoization, ./logging, ./stdlib, ./properties

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
  # Imports = OrderedTable[string, Node]
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
    hasErrors*, nilNotError: bool
    when compileOption("app", "console"):
      cacheEnabled*: bool
    warnings*: seq[Warning]
    currentSelector, lastParent: Node
    imports: Table[string, Stylesheet]
    stylesheets: Stylesheets
    path, filePath, cachePath, dirPath: string

  PrefixFunction = proc(
    p: var Parser,
    excludeOnly, includeOnly: set[TokenKind] = {},
    returnType = ntVoid,
    isFunctionWrap, isCurlyBlock = false,
  ): Node {.gcsafe.}
  InfixFunction = proc(p: var Parser, lhs: Node): Node {.gcsafe.}

const
  tkVars = {tkVarCall}
  tkUnits = {
    tkMM, tkCM, tkIN, tkPX, tkPT, tkPC, tkEM, tkEX, tkCH, tkREM, tkVW, tkVH, tkVMIN,
    tkVMAX, tkMod,
  }
  tkNamedColors = {
    tkColorAliceblue, tkColorAntiquewhite, tkColorAqua, tkColorAquamarine, tkColorAzure,
    tkColorBeige, tkColorBisque, tkColorBlack, tkColorBlanchedalmond, tkColorBlue,
    tkColorBlueviolet, tkColorBrown, tkColorBurlywood, tkColorCadetblue,
    tkColorChartreuse, tkColorChocolate, tkColorCoral, tkColorCornflowerblue,
    tkColorCornsilk, tkColorCrimson, tkColorCyan, tkColorDarkblue, tkColorDarkcyan,
    tkColorDarkgoldenrod, tkColorDarkgray, tkColorDarkgreen, tkColorDarkkhaki,
    tkColorDarkmagenta, tkColorDarkolivegreen, tkColorDarkorange, tkColorDarkorchid,
    tkColorDarkred, tkColorDarksalmon, tkColorDarkseagreen, tkColorDarkslateblue,
    tkColorDarkslategray, tkColorDarkturquoise, tkColorDarkviolet, tkColorDeeppink,
    tkColorDeepskyblue, tkColorDimgray, tkColorDodgerblue, tkColorFirebrick,
    tkColorFloralwhite, tkColorForestgreen, tkColorFuchsia, tkColorGainsboro,
    tkColorGhostwhite, tkColorGold, tkColorGoldenrod, tkColorGray, tkColorGrey,
    tkColorGreen, tkColorGreenyellow, tkColorHoneydew, tkColorHotpink, tkColorIndianred,
    tkColorIndigo, tkColorIvory, tkColorKhaki, tkColorLavender, tkColorLavenderblush,
    tkColorLawngreen, tkColorLemonchiffon, tkColorLightblue, tkColorLightcoral,
    tkColorLightcyan, tkColorLightgoldenrodyellow, tkColorLightgray, tkColorLightgreen,
    tkColorLightpink, tkColorLightsalmon, tkColorLightseagreen, tkColorLightskyblue,
    tkColorLightslategray, tkColorLightsteelblue, tkColorLightyellow, tkColorLime,
    tkColorLimegreen, tkColorLinen, tkColorMagenta, tkColorMaroon,
    tkColorMediumaquamarine, tkColorMediumblue, tkColorMediumorchid,
    tkColorMediumpurple, tkColorMediumseagreen, tkColorMediumslateblue,
    tkColorMediumspringgreen, tkColorMediumturquoise, tkColorMediumvioletred,
    tkColorMidnightblue, tkColorMintcream, tkColorMistyrose, tkColorMoccasin,
    tkColorNavajowhite, tkColorNavy, tkColorOldlace, tkColorOlive, tkColorOlivedrab,
    tkColorOrange, tkColorOrangered, tkColorOrchid, tkColorPalegoldenrod,
    tkColorPalegreen, tkColorPaleturquoise, tkColorPalevioletred, tkColorPapayawhip,
    tkColorPeachpuff, tkColorPeru, tkColorPink, tkColorPlum, tkColorPowderblue,
    tkColorPurple, tkColorRebeccapurple, tkColorRed, tkColorRosybrown, tkColorRoyalblue,
    tkColorSaddlebrown, tkColorSalmon, tkColorSandybrown, tkColorSeagreen,
    tkColorSeashell, tkColorSienna, tkColorSilver, tkColorSkyblue, tkColorSlateblue,
    tkColorSlategray, tkColorSnow, tkColorSpringgreen, tkColorSteelblue, tkColorTan,
    tkColorTeal, tkColorThistle, tkColorTomato, tkColorTurquoise, tkColorViolet,
    tkColorWheat, tkColorWhite, tkColorWhitesmoke, tkColorYellow, tkColorYellowgreen,
  }
  tkAssignable =
    {tkString, tkInteger, tkFloat, tkBool, tkColor, tkAccQuoted} + tkVars + tkNamedColors +
    {tkFnCall, tkIdentifier, tkLB, tkLC}
  tkComparable = tkAssignable + {tkIdentifier, tkFnCall, tkLB, tkLC, tkRC} + tkUnits
  tkTypedLiterals = {
    tkLitArray, tkLitBool, tkLitColor, tkLitFloat, tkLitFunction, tkLitInt, tkLitObject,
    tkLitSize, tkLitString, tkLitStream,
  }
  tkAssignableValue =
    {
      tkString, tkBool, tkFloat, tkInteger, tkIdentifier, tkVarCall, tkColor,
      tkAccQuoted,
    } + tkNamedColors
  tkCompOperators = {tkEQ, tkNE, tkGT, tkGTE, tkLT, tkLTE}
  tkMathOperators = {tkPlus, tkMinus, tkMultiply, tkDivide}
  tkConditional = {tkIf, tkElif, tkElse}

proc hasWarnings*(p: Parser): bool =
  result = p.logger.warnLogs.len != 0

proc getStylesheet*(p: Parser): Stylesheet =
  p.program

proc getStylesheets*(p: Parser): Stylesheets =
  p.stylesheets

#
# Forward declaration
#
proc getPrefixFn(
  p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}
): PrefixFunction

proc getInfixFn(p: var Parser): InfixFunction {.gcsafe.}

proc parseRoot(
  p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}
): Node {.gcsafe.}

proc parsePrefix(
  p: var Parser,
  excludeOnly, includeOnly: set[TokenKind] = {},
  returnType = ntVoid,
  isFunctionWrap, isCurlyBlock = false,
): Node {.gcsafe.}

proc parseInfix(p: var Parser, lhs: Node): Node {.gcsafe.}

proc parseStatement(
  p: var Parser,
  parent: (TokenTuple, Node),
  excludeOnly, includeOnly: set[TokenKind] = {},
  returnType = ntVoid,
  isFunctionWrap, isCurlyBlock = false,
): Node {.gcsafe.}

proc parseSelectorStmt(
  p: var Parser,
  parent: (TokenTuple, Node),
  excludeOnly, includeOnly: set[TokenKind] = {},
  returnType = ntVoid,
  isFunctionWrap, isCurlyBlock = false,
) {.gcsafe.}

proc pIdentCall(
  p: var Parser,
  excludeOnly, includeOnly: set[TokenKind] = {},
  returnType = ntVoid,
  isFunctionWrap, isCurlyBlock = false,
): Node {.gcsafe.}

proc pFunctionCall(
  p: var Parser,
  excludeOnly, includeOnly: set[TokenKind] = {},
  returnType = ntVoid,
  isFunctionWrap, isCurlyBlock = false,
): Node {.gcsafe.}

proc pClassSelector(
  p: var Parser,
  excludeOnly, includeOnly: set[TokenKind] = {},
  returnType = ntVoid,
  isFunctionWrap, isCurlyBlock = false,
): Node {.gcsafe.}

proc getPrefixOrInfix(
  p: var Parser,
  includeOnly, excludeOnly: set[TokenKind] = {},
  infix: Node = nil,
  isFunctionWrap, isCurlyBlock = false,
): Node {.gcsafe.}

# proc parseVarCall(p: var Parser, tk: TokenTuple, varName: string, isFunctionWrap = false): Node

# proc importModule(th: ModuleThreadArgs) {.thread.}
# proc moduleImporter(path, dirPath: string, results: ptr CountTable[Stylesheet], L: ptr TicketLock)
# proc importer(fpath, dirPath: string; results: ptr CountTable[Stylesheet]; L: ptr TicketLock)

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

macro prefixHandle(name, body: untyped) =
  # Create a new prefix procedure with `name` and `body`
  newProc(
    name,
    [
      ident("Node"), # return type
      nnkIdentDefs.newTree(
        ident("p"), nnkVarTy.newTree(ident("Parser")), newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident("excludeOnly"),
        ident("includeOnly"),
        nnkBracketExpr.newTree(ident("set"), ident("TokenKind")),
        newNimNode(nnkCurly),
      ),
      nnkIdentDefs.newTree(ident("returnType"), newEmptyNode(), ident("ntVoid")),
      nnkIdentDefs.newTree(
        ident("isFunctionWrap"), ident("isCurlyBlock"), newEmptyNode(), ident("false")
      ),
    ],
    body,
    pragmas = newNimNode(nnkPragma).add(ident("gcsafe")),
  )

proc use(node: Node) =
  ## Mark a callable (function or variable) as used
  case node.nt
  of ntVariable:
    node.varUsed = true
  of ntFunction, ntMixin:
    node.fnUsed = true
  # of ntCall:
  # if node.callNode.nt == ntVariable:
  # node.callNode.varUsed = true
  else:
    discard

proc getLiteralType(p: var Parser): NodeType =
  result =
    case p.curr.kind
    of tkLitArray: ntArray
    of tkLitBool: ntBool
    of tkLitColor: ntColor
    of tkLitFloat: ntFloat
    of tkLitFunction: ntFunction
    of tkLitInt: ntInt
    of tkLitObject: ntObject
    of tkLitSize: ntSize
    of tkLitString: ntString
    of tkLitMixin: ntMixin
    of tkLitStream: ntStream
    of tkLitVoid: ntVoid
    else: ntInvalid

proc getOpStr(tk: TokenTuple): string =
  result =
    case tk.kind
    of tkEQ: "=="
    of tkNE: "!="
    of tkLT: "<"
    of tkLTE: "<="
    of tkGT: ">"
    of tkGTE: ">="
    else: ""

# proc nextToken(p: var Parser, kind: TokenKind): bool = p.next.kind == kind
# proc nextToken(p: var Parser, kind: set[TokenKind]): bool = p.next.kind in kind

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
  p.next.kind == tkLP and p.next.line == p.curr.line and p.next.wsno == 0

template expectWalk(kind: TokenKind) =
  if likely(p.curr is kind):
    walk p
  else:
    return nil

template expect(kind: TokenKind, body) =
  if likely(p.curr is kind):
    body
  else:
    return nil

template expect(kind: set[TokenKInd], body) =
  if likely(p.curr in kind):
    body
  else:
    return nil

template expectNot(kind: set[TokenKind], body) =
  if likely(p.curr notin kind):
    body
  else:
    return nil

template notnil(x: Node, body): untyped =
  if likely(x != nil):
    body
  else:
    return nil

template notnil(x: Node, body, elseBody) =
  if likely(x != nil): body else: elseBody

proc toUnits(kind: TokenKind): Units =
  case kind
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
  of tkMod: PSIZE
  else: VMAX

template checkColon() =
  if p.curr is tkColon:
    walk p
  else:
    error(badIndentation, p.curr)

#
# Parse Literals
#
include handlers/pLiteral

prefixHandle parseComment:
  # todo support multi-line comments
  result = newComment("") # we don't need to store comments
  walk p

prefixHandle parseDocBlock:
  result = newDocBlock(p.curr.value)
  walk p

# Variable Declaration & Assignments
include
  handlers/[pImport, pExtend, pAssignment, pCond, pFor, pCommand, pFunction, pSelector]

prefixHandle pClassSelector:
  walk p # tkDot
  # if unlikely(p.isFnCall()):
  #   let fnCall = p.parseCallFnCommand(includeOnly, excludeOnly)
  #   result = ast.newNode(Node(), fnCall)
  #   return # result
  p.curr.kind = tkClass
  p.curr.value = "." & p.curr.value
  return p.parseClass(excludeOnly, includeOnly)

# Prefix or Infix
proc getPrefixOrInfix(
    p: var Parser,
    includeOnly, excludeOnly: set[TokenKind] = {},
    infix: Node = nil,
    isFunctionWrap, isCurlyBlock = false,
): Node {.gcsafe.} =
  let lhs = p.parsePrefix(excludeOnly, includeOnly, isFunctionWrap = isFunctionWrap)
  var infixNode: Node
  if p.curr.isInfix:
    if likely(lhs != nil):
      infixNode = p.parseInfix(lhs)
      if likely(infixNode != nil):
        return infixNode
    else:
      return
  result = lhs

proc parseMathExp(p: var Parser, lhs: Node): Node {.gcsafe.}
proc parseCompExp(p: var Parser, lhs: Node): Node {.gcsafe.}

proc parseCompExp(p: var Parser, lhs: Node): Node {.gcsafe.} =
  # parse logical expressions with symbols (==, !=, >, >=, <, <=)
  let op = getInfixOp(p.curr.kind, false)
  walk p
  let rhsToken = p.curr
  let rhs = p.parsePrefix(includeOnly = tkComparable)
  if likely(rhs != nil):
    result = newInfix(lhs, rhsToken)
    result.infixOp = op
    if p.curr.kind in tkMathOperators:
      result.infixRight = p.parseMathExp(rhs)
    else:
      result.infixRight = rhs

proc parseMathExp(p: var Parser, lhs: Node): Node {.gcsafe.} =
  # parse math expressions with symbols (+, -, *, /)
  let infixOp = getInfixMathOp(p.curr.kind, false)
  walk p
  let rhs = p.parsePrefix(includeOnly = tkComparable)
  if likely(rhs != nil):
    result = newInfixCalc(lhs)
    result.mathInfixOp = infixOp
    case p.curr.kind
    of tkMultiply, tkDivide:
      result.mathRight = p.parseMathExp(rhs)
    of tkPlus, tkMinus:
      result.mathRight = rhs
      result = p.parseMathExp(result)
    else:
      result.mathRight = rhs

proc getInfixFn(p: var Parser): InfixFunction {.gcsafe.} =
  case p.curr.kind
  of tkCompOperators: parseCompExp
  of tkMathOperators: parseMathExp
  else: nil

proc parseInfix(p: var Parser, lhs: Node): Node {.gcsafe.} =
  var infixNode: Node # ntInfixExpr
  let infixFn = p.getInfixFn()
  if likely(infixFn != nil):
    result = p.infixFn(lhs)
  if p.curr in tkCompOperators:
    result = p.parseCompExp(result)

#
# Statement List
#
template stmtStyle(): untyped =
  if likely(isCurlyBlock == false):
    (p.curr.line > parent[0].line and p.curr.pos > parent[0].pos)
  else:
    (p.curr.kind != tkRC)

template checkStmtEnd() =
  if unlikely(isCurlyBlock):
    if likely(p.curr is tkRC):
      walk p
    else:
      error(missingRC, parent[0])

proc parseStatement(
    p: var Parser,
    parent: (TokenTuple, Node),
    excludeOnly, includeOnly: set[TokenKind] = {},
    returnType = ntVoid,
    isFunctionWrap, isCurlyBlock = false,
): Node =
  if p.lastParent == nil:
    p.lastParent = parent[1]
  if p.curr isnot tkEOF:
    result = newStmt()
    var tk = p.curr
    while p.curr isnot tkEOF and stmtStyle:
      tk = p.curr
      let node = p.parsePrefix(excludeOnly, includeOnly, returnType, isFunctionWrap)
      notnil node:
        add result.stmtList, node
      p.lastParent = nil
    if result.stmtList.len == 0:
      return nil # Nestab
  checkStmtEnd

proc parseSelectorStmt(
    p: var Parser,
    parent: (TokenTuple, Node),
    excludeOnly, includeOnly: set[TokenKind] = {},
    returnType = ntVoid,
    isFunctionWrap, isCurlyBlock = false,
) =
  var isCurlyBlock: bool
  if unlikely(p.curr is tkLC):
    isCurlyBlock = true
    walk p
  if p.curr isnot tkEOF:
    while p.curr isnot tkEOF and stmtStyle:
      let
        curr = p.curr
        node = p.parsePrefix(excludeOnly, includeOnly, returnType, isFunctionWrap)
      notnil node:
        p.lastParent = parent[1]
        case node.nt
        of ntProperty:
          parent[1].properties[node.pName] = node
          if unlikely(node.pShared.len > 0):
            for sharedProp in node.pShared:
              sharedProp.pVal = node.pVal
              parent[1].properties[sharedProp.pName] = sharedProp
              node.pShared.setLen(0)
        of ntCaseStmt, ntCondStmt, ntVariable, ntAssign, ntIdent, ntForStmt:
          parent[1].innerNodes[$genOid()] = node
        of ntExtend, ntComment:
          discard
        of ntCallFunction:
          if node.fnCallReturnType in
              {
                ntProperty, ntTagSelector, ntClassSelector, ntPseudoSelector,
                ntIDSelector,
              }:
            # todo implement types for CSS selectors 
            parent[1].innerNodes[$genOid()] = node
          else:
            error(invalidCallContext, p.prev)
        of ntClassSelector, ntIDSelector, ntPseudoSelector, ntTagSelector:
          node.parents = concat(node.parents, parent[1].multipleSelectors)
          if likely(parent[1].innerNodes.hasKey(node.ident) == false):
            parent[1].innerNodes[node.ident] = node
          else:
            for k, v in node.innerNodes:
              parent[1].innerNodes[node.ident].innerNodes[k] = v
        else:
          errorWithArgs(unexpectedToken, curr, [curr.value])
      do:
        discard
    p.lastParent = nil
  checkStmtEnd

#
# Prefix Statements
#
proc getPrefixFn(
    p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}
): PrefixFunction =
  if excludeOnly.len > 0:
    if p.curr in excludeOnly:
      errorWithArgs(invalidContext, p.curr, [p.curr.value])
  if includeOnly.len > 0:
    if p.curr notin includeOnly:
      errorWithArgs(invalidContext, p.curr, [p.curr.value])
  case p.curr.kind
  of tkIdentifier, tkMixCall:
    if p.isFnCall or p.curr is tkMixCall:
      pFunctionCall
    elif p.next isnot tkColon and (p.next is tkLC or p.next.line > p.curr.line):
      parseSelectorTag
    elif tkIdentifier notin excludeOnly and tkFnCall notin includeOnly:
      parseProperty
    else:
      nil
  of tkDot:
    pClassSelector
  of tkInteger:
    parseInt
  of tkFloat:
    parseFloat
  of tkColor:
    parseColor
  of tkString:
    parseString
  of tkVarCall:
    pIdentCall
  of tkVarAssgn:
    parseAssignment
  of tkVar, tkConst:
    pVarDecl
  of tkReturn:
    parseReturnCommand
  of tkEcho:
    parseEchoCommand
  of tkBool:
    parseBool
  of tkLB:
    parseAnoArray
  of tkLC:
    parseAnoObject
  of tkCase:
    parseCase
  of tkIf:
    parseCond
  of tkFor:
    parseFor
  of tkFnDef, tkMixDef:
    parseFn
  of tkComment:
    parseComment
  of tkExtend:
    parseExtend
  of tkThis:
    parseThis
  of tkAccQuoted:
    parseAccQuoted
  of tkNamedColors:
    parseNamedColor
  of tkAssert:
    parseAssert
  of tkDoc:
    parseDocBlock
  of tkAmp:
    pMultiSelector
  else:
    if p.next isnot tkColon: parseSelectorTag else: nil

proc parsePrefix(
    p: var Parser,
    excludeOnly, includeOnly: set[TokenKind] = {},
    returnType = ntVoid,
    isFunctionWrap, isCurlyBlock = false,
): Node =
  let prefixFn = p.getPrefixFn(excludeOnly, includeOnly)
  if likely(prefixFn != nil):
    return p.prefixFn(excludeOnly, includeOnly, returnType, isFunctionWrap)
  result = nil

proc parseRoot(
    p: var Parser, excludeOnly, includeOnly: set[TokenKind] = {}
): Node {.gcsafe.} =
  # Parse nodes at root-level
  result =
    case p.curr.kind
    of tkDot:
      p.pClassSelector(excludeOnly, includeOnly)
    of tkID:
      p.parseSelectorID(excludeOnly, includeOnly)
    of tkVarDefRef, tkVarAssgn:
      p.parseAssignment()
    of tkVar, tkConst:
      p.pVarDecl()
    of tkVarCall:
      p.pIdentCall()
    of tkFnDef, tkMixDef:
      p.parseFn()
    of tkComment:
      p.parseComment()
    of tkIf:
      p.parseCond(excludeOnly, includeOnly)
    of tkCase:
      p.parseCase(excludeOnly, includeOnly)
    of tkEcho:
      p.parseEchoCommand()
    of tkAssert:
      p.parseAssert()
    of tkFor:
      p.parseFor(excludeOnly, includeOnly)
    of tkImport:
      p.parseImport(excludeOnly, includeOnly)
    of tkIdentifier:
      if p.next.kind == tkLP and p.next.line == p.curr.line:
        p.pFunctionCall(excludeOnly, includeOnly)
      else:
        p.parseSelectorTag(excludeOnly, includeOnly)
    of tkMultiply:
      p.parseUniversalSelector(excludeOnly, includeOnly)
    of tkDoc:
      p.parseDocBlock(excludeOnly, includeOnly)
    else:
      nil
  if unlikely(result == nil):
    if not p.nilNotError:
      let tk = if p.curr isnot tkEOF: p.curr else: p.prev
      errorWithArgs(unexpectedToken, tk, [tk.value])
    else:
      p.nilNotError = false

template startParseStylesheet(src, path: string) =
  p.lex = tokens.newLexer(src, allowMultilineStrings = true)
  when defined wasm:
    p.logger = Logger(filePath: "")
  else:
    p.logger = Logger(filePath: path)
  p.propsTable = initPropsTable()
  p.program = Stylesheet()
  p.program.sourcePath = path
  initstdlib()
  p.importSystemModule()
  p.curr = p.lex.getToken()
  p.next = p.lex.getToken()
  while p.curr isnot tkEOF:
    if p.lex.hasError:
      p.logger.newError(internalError, p.curr.line, p.curr.col, false, [p.lex.getError])
    if p.hasErrors:
      break
    let node = p.parseRoot(excludeOnly = {tkExtend, tkPseudo, tkReturn})
    if likely(node != nil):
      add p.program.nodes, node
    # else: break
  p.lex.close()

proc parseStylesheet*(src, path: string, enableCache = false): Parser =
  var p = Parser()
  when not defined wasm:
    p.filePath = path
    p.dirPath = path.parentDir()
    p.path = path.parentDir()
  when compileOption("app", "console"):
    p.cacheEnabled = enableCache
  startParseStylesheet(src, path)
  # for k, v in p.program.getStack:
  #   # check for unused variables/functions
  #   case v.nt:
  #   of ntVariable:
  #     if unlikely(v.varUsed == false):
  #       p.logger.warn(declaredNotUsed, v.varMeta.line, v.varMeta.pos, true, k)
  #   of ntFunction, ntMixin:
  #     if unlikely(v.fnUsed == false):
  #       p.logger.warn(declaredNotUsed, v.fnMeta.line, v.fnMeta.pos, true, v.fnName)
  #   else: discard
  result = p
