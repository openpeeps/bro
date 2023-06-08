# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import pkg/stashtable
import pkg/[msgpack4nim, msgpack4nim/msgpack4collection]
import pkg/kapsis/cli
import std/[os, strutils, sequtils, macros, tables, json,
            memfiles, critbits, threadpool, times, oids]

import ./tokens, ./ast, ./memtable, ./logging
import ./properties

when not defined release:
  import std/[jsonutils] 

export logging

type
  ParserType = enum
    Main
    Partial 

  Warning* = tuple[msg: string, line, col: int]

  # PartialFilePath = distinct string
  # Importer* = ref object
  #   partials: OrderedTableRef[int, tuple[indentation: int, sourcePath: string]]
  #   sources: TableRef[string, MemFile]

  
  Memparser = StashTable[string, Program, 1000]
  Imports = OrderedTableRef[string, Node]

  Parser* = object
    lex: Lexer
    prev, curr, next: TokenTuple
    program: Program
    memtable: Memtable
    when compileOption("app", "console"):
      error: seq[Row]
      logger*: Logger
    else:
      error: string
    hasErrors*: bool
    warnings*: seq[Warning]
    currentSelector: Node
    imports: Imports
    memparser: Memparser
    case ptype: ParserType
    of Main:
      projectDirectory: string
    else: discard
    filePath: string

  PrefixFunction = proc(p: var Parser, scope: ScopeTable = nil): Node
  InfixFunction = proc(p: var Parser, scope: ScopeTable = nil): Node
  # PartialChannel = tuple[status: string, program: Program]

# forward definition
proc getPrefix(p: var Parser, kind: TokenKind): PrefixFunction
proc parse(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node
proc parseVariableCall(p: var Parser, scope: ScopeTable = nil): Node
proc parseVariableAccessor(p: var Parser, scope: ScopeTable = nil): Node
proc parseInfix(p: var Parser, scope: ScopeTable = nil): Node
proc partialThread(th: (string, Memparser)) {.thread.}

when compileOption("app", "console"):
  template err(msg: string) =
    let pos = if p.curr.pos == 0: 0 else: p.curr.pos + 1
    add p.error, @[span("Error ($2:$3): $1" % [msg, $p.curr.line, $pos])]

  template err(msg: string, tk: TokenTuple, sfmt: varargs[string]) =
    let pos = if tk.pos == 0: 0 else: tk.pos + 1
    var newRow: Row
    add newRow, span("Error", fgRed, indentSize = 0)
    add newRow, span("(" & $tk.line & ":" & $pos & ")")
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
    let pos = if tk.pos == 0: 0 else: tk.pos + 1
    p.error = "Error ($2:$3): $1" % [msg, $p.curr.line, $pos]

  template err(msg: string, tk: TokenTuple, sfmt: varargs[string]) =
    var errmsg = msg
    for str in sfmt:
      add errmsg, indent("\"" & str & "\"", 1)  
    let pos = if tk.pos == 0: 0 else: tk.pos + 1 
    p.error = "Error ($2:$3): $1" % [errmsg, $tk.line, $pos]
    return

  proc getError*(p: Parser): string =
    result =
      if p.error.len != 0: p.error
      else: p.lex.getError

proc hasError*(p: Parser): bool =
  result = p.error.len != 0 or p.lex.hasError

proc hasWarnings*(p: Parser): bool =
  result = p.logger.warnLogs.len != 0

const tkPropsName = {tkRuby, tkStrong}

when not defined release:
  proc `$`(node: Node): string =
    # print nodes while in dev mode
    result = pretty(node.toJson(), 2)

  proc `$`(program: Program): string =
    # print nodes while in dev mode
    result = pretty(program.toJson(), 2)

macro definePseudoClasses() =
  # https://developer.mozilla.org/en-US/docs/Web/CSS/:host_function
  var pseudoTable = nnkTableConstr.newTree()
  let keys = [("active", 0), ("any-link", 0), ("autofill", 0), ("blank", 0),
    ("checked", 0), ("current", 0), ("default", 0), ("defined", 0), ("dir", 1),
    ("disabled", 0), ("empty", 0), ("enabled", 0), ("first", 0), ("first-child", 0),
    ("focus", 0), ("focus-visible", 0), ("fullscreen", 0), ("future", 0), ("has", -1),
    ("host", -1), ("host-context", 1), ("hover", 0), ("in-range", 0), ("indeterminate", 0),
    ("invalid", 0), ("is", -1), ("lang", 1), ("last-child", 0), ("last-of-type", 0),
    ("left", 0), ("link", 0), ("link", 0), ("local-link", 0), ("modal", 0), ("not", -1),
    ("nth-child", 1), ("nth-col", 1), ("nth-last-child", 1), ("nth-last-col", 1),
    ("nth-last-of-type", 1), ("nth-of-type", 1), ("only-child", 0), ("only-of-type", 0),
    ("optional", 0), ("out-of-range", 0), ("past", 0), ("paused", 0), ("picture-in-picture", 0),
    ("placeholder-shown", 0), ("playing", 0), ("read-only", 0), ("read-write", 0), ("required", 0),
    ("right", 0), ("root", 0), ("scope", 0), ("target", 0), ("target-within", 0), ("user-invalid", 0),
    ("user-valid", 0), ("valid", 0), ("visited", 0), ("where", -1) # https://developer.mozilla.org/en-US/docs/Web/CSS/:where
  ]
  for k in keys:
    var node = newTree(nnkExprColonExpr, newLit k[0], newLit k[1])
    add pseudoTable, node
  result =
    newStmtList(
      newLetStmt(
        ident "pseudoTable",
        newCall(newDotExpr(pseudoTable, ident "toCritBitTree"))
      )
  )

definePseudoClasses()

const
  tkVars = {tkVarCall, tkVar}
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
  tkAssignable = {tkString, tkInteger, tkBool, tkColor} + tkVars + tkNamedColors
  tkComparable = tkAssignable
  tkAssignableFn = {tkJSON}
  tkAssignableValue = {tkString, tkBool, tkFloat, tkInteger, tkIdentifier, tkVarCall, tkColor} + tkNamedColors
  tkOperators = {tk_EQ, tk_NE, tk_GT, tk_GTE, tk_LT, tk_LTE}
  tkConditional = {tkIf, tkElif, tkElse}
  tkNativeFn = {
    tkCSSCalc
  }

proc walk(p: var Parser, offset = 1) =
  var i = 0
  while offset > i:
    inc i
    p.prev = p.curr
    p.curr = p.next
    p.next = p.lex.getToken()

proc expect(p: var Parser, kind: TokenKind): bool =
  result = p.curr.kind == kind

proc nextExpect(p: var Parser, kind: TokenKind): bool =
  result = p.next.kind == kind

proc expect(p: var Parser, kind: set[TokenKind]): bool =
  result = p.curr.kind in kind

proc nextExpect(p: var Parser, kind: set[TokenKind]): bool =
  result = p.next.kind in kind
  if not result: error(UnexpectedToken, p.curr)

proc isColor(tk: TokenTuple): bool =
  result = tk.kind in tkNamedColors

proc getAssignableNode(p: var Parser, scope: ScopeTable): Node =
  case p.curr.kind:
  of tkColor, tkNamedColors:
    result = newColor p.curr.value
    walk p
  of tkString:
    result = newString p.curr.value
    walk p
  of tkInteger:
    result = newInt p.curr.value
    walk p
  of tkBool:
    result = newBool p.curr.value
    walk p
  of tkVarCall:
    result = p.parseVariableCall(scope)
  else:
    if p.curr.isColor:
      result = newColor(p.curr.value)
      walk p

proc tkNot(p: var Parser, expKind: TokenKind): bool =
  result = p.curr.kind != expKind

proc tkNot(p: var Parser, expKind: set[TokenKind]): bool =
  result = p.curr.kind notin expKind

proc isProp(p: var Parser): bool =
  result = p.curr.kind == tkIdentifier

proc childOf(p: var Parser, tk: TokenTuple): bool =
  result = p.curr.pos > tk.pos and p.curr.kind != tkEOF

proc isPropOf(p: var Parser, tk: TokenTuple): bool =
  result = p.childOf(tk) and p.isProp()

proc parseComment(p: var Parser, scope: ScopeTable = nil): Node =
  discard newComment(p.curr.value)
  walk p

proc getNil(p: var Parser): Node =
  result = nil
  walk p

proc parseFnStmt(p: var Parser, scope: ScopeTable = nil): Node =
  discard

proc parseFnCall(p: var Parser, scope: ScopeTable = nil): Node =
  discard

include ./parseutils/extendStmt
include ./parseutils/selector
include ./parseutils/varStmt
include ./parseutils/importStmt
include ./parseutils/forStmt
include ./parseutils/condStmt
include ./parseutils/caseStmt

proc parsePreview(p: var Parser, scope: ScopeTable = nil): Node =
  result = newPreview(p.curr)
  walk p

proc parseTag(p: var Parser, scope: ScopeTable = nil): Node =
  let tk = p.curr
  result = p.parseSelector(tk.newTag, tk, scope)

proc getInfix(p: var Parser, kind: TokenKind): InfixFunction =
  discard
  # case p.curr.kind:
  # of tkPLus:
  # of tkMinus:

proc parseEcho(p: var Parser, scope: ScopeTable = nil): Node =
  if p.nextExpect(tkAssignableValue):
    walk p
    result = newEcho(p.getAssignableNode(scope))

proc parseNativeFn(p: var Parser, scope: ScopeTable = nil): Node =
  discard

proc getPrefix(p: var Parser, kind: TokenKind): PrefixFunction =
  case p.curr.kind:
  # of tkRoot:
    # parseRoot
  of tkClass:
    parseClass
  of tkID:
    parseID
  of tkComment:
    parseComment
  of tkAnd:
    parseNest
  of tkPseudoClass:
    parsePseudoNest
  of tkVar:
    parseVariable
  of tkVarCall:
    parseVariableCall
  of tkVarCallAccessor:
    parseVariableAccessor
  of tkFunctionCall:
    parseFnCall
  of tkFunctionStmt:
    parseFnStmt
  of tkImport:
    parseImport
  of tkPreview:
    parsePreview
  of tkExtend:
    parseExtend
  of tkFor:
    parseForStmt
  of tkCase:
    parseCaseStmt
  of tkIdentifier:
    parseTag
  of tkIf:
    parseCondStmt
  of tkEcho:
    parseEcho
  of tkNativeFn:
    parseNativeFn
  else: nil

proc parse(p: var Parser, scope: ScopeTable = nil, excludeOnly, includeOnly: set[TokenKind] = {}): Node =
  if excludeOnly.len != 0 and includeOnly.len == 0:
    # check if any `excludeOnly` TokenKind to look for
    if p.curr.kind in excludeOnly:
      error(UnexpectedToken, p.curr, p.curr.value)
      return
  elif includeOnly.len != 0 and excludeOnly.len == 0:
    # check if any `includeOnly` TokenKind to look for
    if p.curr.kind notin includeOnly:
      error(UnexpectedToken, p.curr, p.curr.value)
      return
  let callFunction = p.getPrefix(p.curr.kind)
  if callFunction != nil:
    let node = p.callFunction(scope)
    result = node
  else:
    if not p.hasErrors:
      error(UnrecognizedToken, p.curr, p.curr.value)

proc getProgram*(p: Parser): Program =
  ## Return current AST as `Program`
  result = p.program

proc getMemtable*(p: Parser): Memtable =
  ## Return data stored in memory as `Memtable`
  result = p.memtable

template initParser(fpath: string) =
  result.lex = Lexer.init(readFile(fpath))
  result.program = Program()
  result.memtable = Memtable()
  result.curr = result.lex.getToken()
  result.next = result.lex.getToken()
  result.logger = Logger(filePath: fpath)
  while not result.hasError:
    if result.curr.kind == tk_EOF: break
    let node = result.parse(excludeOnly = {tkExtend, tkPseudoClass})
    if likely(node != nil):
      result.program.nodes.add(node)
    else: break

  result.lex.close()
  proc warnUnusedVar(p: var Parser, k: string, v: Node) =
    p.logger.warn(DeclaredVariableUnused, v.varMeta.line, v.varMeta.col, true, "$" & k)
  for k, v in result.memtable.pairs():
    case v.varValue.nt:
    of NTArray:
      if unlikely(v.varValue.usedArray == false):
        result.warnUnusedVar(k, v)
    of NTObject:
      if unlikely(v.varValue.usedObject == false):
        result.warnUnusedVar(k, v)
    of NTJsonValue:
      if unlikely(v.varValue.usedJson == false):
        result.warnUnusedVar(k, v)
    else:
      if unlikely(v.varValue.used == false):
        result.warnUnusedVar(k, v)
  # result.program.info = ("0.1.0", now())

proc partialThread(th: (string, Memparser)) {.thread.} =
  {.gcsafe.}:
    proc newImporter(): Parser =
      result = Parser(ptype: Partial, filePath: th[0])
      initParser(th[0])
    th[1].withValue(th[0]):
      value[] = newImporter().getProgram
    # var s = MsgStream.init()
    # s.pack(p.getProgram)
    # s.pack_bin(sizeof(p.getProgram))
    # writeFile(th[0].parentDir / "cache" / "test.partial.ast", s.data)
    # let p = newImportParser()
    # discard th[1].insert(p.filePath, p) 

proc parseProgram*(fpath: string): Parser =
  ## Parse program and return `Parser` instance
  result = Parser(ptype: Main, filePath: fpath, imports: Imports(),
              memparser: newStashTable[string, Program, 1000]())
  result.projectDirectory = fpath.parentDir()
  initParser(fpath)
  # resolve deferred imports
  # echo result.memparser.len
  # for k, index in result.memparser.keys:
  #   result.memparser.withFound(k, index):
  #     echo k
  #     echo value == nil
  #     result.imports[k].importNodes = value.nodes
  # echo result.getProgram