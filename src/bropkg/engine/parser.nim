# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

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
    # imports: Importer
    currentSelector: Node
    ptrNodes: Table[string, Node]
    redundancy: Table[string, Node]
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
proc parseInfix(p: var Parser, scope: ScopeTable = nil): Node
proc partialThread(fpath: string, lastModified: Time): Parser {.thread.}

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
  result = p.warnings.len != 0

const tkPropsName = {TKRuby, TKStrong}

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

proc walk(p: var Parser, offset = 1) =
  var i = 0
  while offset > i:
    inc i
    p.prev = p.curr
    p.curr = p.next
    p.next = p.lex.getToken()

const
  tkVars = {TKVarCall, TKVar}
  tkAssignable = {TKString, TKInteger, TKBool, TKColor} + tkVars
  tkComparable = tkAssignable
  tkAssignableFn = {TKJSON}
  tkAssignableValue = {TKString, TKBool, TKFloat, TKInteger, TKIdentifier, TKVarCall}
  tkOperators = {TK_EQ, TK_NE, TK_GT, TK_GTE, TK_LT, TK_LTE}
  tkConditional = {TKIf, TKElif, TKElse}
var tkNamedColors = ["aliceblue", "antiquewhite", "aqua", "aquamarine", "azure", "beige",
    "bisque", "black", "blanchedalmond", "blue", "blueviolet", "brown",
    "burlywood", "cadetblue", "chartreuse", "chocolate", "coral", "cornflowerblue",
    "cornsilk", "crimson", "cyan", "darkblue", "darkcyan", "darkgoldenrod",
    "darkgray", "darkgreen", "darkkhaki", "darkmagenta", "darkolivegreen",
    "darkorange", "darkorchid", "darkred", "darksalmon", "darkseagreen",
    "darkslateblue", "darkslategray", "darkturquoise", "darkviolet",
    "deeppink", "deepskyblue", "dimgray", "dodgerblue", "firebrick",
    "floralwhite", "forestgreen", "fuchsia", "gainsboro", "ghostwhite",
    "gold", "goldenrod", "gray", "grey", "green", "greenyellow", "honeydew",
    "hotpink", "indianred", "indigo", "ivory", "khaki", "lavender",
    "lavenderblush", "lawngreen", "lemonchiffon", "lightblue", "lightcoral",
    "lightcyan", "lightgoldenrodyellow", "lightgray", "lightgreen", "lightpink",
    "lightsalmon", "lightseagreen", "lightskyblue", "lightslategray",
    "lightsteelblue", "lightyellow", "lime", "limegreen", "linen", "magenta",
    "maroon", "mediumaquamarine", "mediumblue", "mediumorchid", "mediumpurple",
    "mediumseagreen", "mediumslateblue", "mediumspringgreen", "mediumturquoise",
    "mediumvioletred", "midnightblue", "mintcream", "mistyrose", "moccasin",
    "navajowhite", "navy", "oldlace", "olive", "olivedrab", "orange", "orangered",
    "orchid", "palegoldenrod", "palegreen", "paleturquoise", "palevioletred",
    "papayawhip", "peachpuff", "peru", "pink", "plum", "powderblue",
    "purple", "rebeccapurple", "red", "rosybrown", "royalblue", "saddlebrown",
    "salmon", "sandybrown", "seagreen", "seashell", "sienna", "silver", "skyblue",
    "slateblue", "slategray", "snow", "springgreen", "steelblue", "tan",
    "teal", "thistle", "tomato", "turquoise", "violet", "wheat", "white",
    "whitesmoke", "yellow", "yellowgreen"].toCritBitTree # todo macro

proc isColor(tk: TokenTuple): bool =
  result = tk.value in tkNamedColors

proc getAssignableNode(p: var Parser, scope: ScopeTable): Node =
  case p.curr.kind:
  of TKColor:
    result = newColor p.curr.value
    walk p
  of TKString:
    result = newString p.curr.value
    walk p
  of TKInteger:
    result = newInt p.curr.value
    walk p
  of TKBool:
    result = newBool p.curr.value
    walk p
  of TKVarCall:
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
  result = p.curr.kind == TKIdentifier

proc childOf(p: var Parser, tk: TokenTuple): bool =
  result = p.curr.pos > tk.pos and p.curr.kind != TKEOF

proc isPropOf(p: var Parser, tk: TokenTuple): bool =
  result = p.childOf(tk) and p.isProp()

proc parseComment(p: var Parser, scope: ScopeTable = nil): Node =
  discard newComment(p.curr.value)
  walk p

proc getVNode(tk: TokenTuple): TokenTuple =
  result = tk

proc parseExtend(p: var Parser, scope: ScopeTable = nil): Node =
  walk p
  case p.curr.kind
  of TKClass, TKID:
    if p.ptrNodes.hasKey(p.curr.value):
      if p.currentSelector.ident notin p.ptrNodes[p.curr.value].multipleSelectors:
        p.currentSelector.extends = true
        p.ptrNodes[p.curr.value].multipleSelectors.add(p.currentSelector.ident)
        walk p
      else:
        error(ExtendRedundancyError, p.curr, true, p.currentSelector.ident, p.ptrNodes[p.curr.value].ident)
    else:
      error(UndeclaredCSSSelector, p.curr, p.curr.value)
  else: discard # todo

proc parseProperty(p: var Parser, scope: ScopeTable = nil): Node =
  if likely(Properties.hasKey(p.curr.value)):
    let pName = p.curr
    walk p
    if p.curr.kind == TKColon:
      walk p
      result = newProperty(pName.value)
      while p.curr.line == pName.line:
        case p.curr.kind
        of {TKIdentifier, TKColor, TKString, TKCenter} + tkPropsName:
          let property = Properties[pName.value]
          let propValue = getVNode(p.curr)
          let checkValue = property.hasStrictValue(p.curr.value)
          if checkValue.exists:
            if checkValue.status in {Unimplemented, Deprecated, Obsolete, NonStandard}:
              warn(UnstablePropertyStatus, p.curr, true,
                      pName.value & ": " & p.curr.value, $checkValue.status)
          result.pVal.add newString(p.curr.value)
          walk p
          # else:
          #   walk p
          #   error("Invalid value $",
          #     p.prev, true,
          #     extraLines = property.getValues(),
          #     extraLabel = "Available values:",
          #     pName.value & ": " & p.prev.value
          #   )
        of TKInteger:
          result.pVal.add newInt(p.curr.value)
          walk p
        of TKFloat:
          result.pVal.add newFloat(p.curr.value)
          walk p
        of TKVarCall:
          let callNode = p.parseVariableCall(scope)
          if callNode != nil:
            result.pVal.add(deepCopy(callNode))
          else:
            walk p
            return
        else:
          break # TODO error
      case p.curr.kind:
      of TKImportant:
        result.pRule = propRuleImportant
        walk p
      of TKDefault:
        result.pRule = propRuleDefault
        walk p
      else: discard
    else:
      error(MissingAssignmentToken, p.curr)
  else:
    error(InvalidProperty, p.curr, true, p.curr.value)

proc whileChild(p: var Parser, this: TokenTuple, parentNode: Node, scope: ScopeTable) =
  while p.curr.pos > this.pos and p.curr.kind != TKEOF:
    let tk = p.curr
    if p.isPropOf(this):
      let propNode = p.parseProperty(scope)
      if likely(propNode != nil):
        parentNode.props[propNode.pName] = propNode
      else: return
    elif p.childOf(this):
      if unlikely(p.curr.kind == TKExtend):
        discard p.parseExtend(scope)
        if p.hasErrors: return # any errors from `parseExtend`
        continue
      let node = p.parse(scope, excludeOnly = {TKImport})
      if node != nil:
        case node.nt
        of NTForStmt:
          parentNode.props[$node.forOid] = node
        of NTCondStmt:
          parentNode.props[$node.condOid] = node
        of NTCaseStmt:
          parentNode.props[$node.caseOid] = node
        else:
          node.parents = concat(@[parentNode.ident], parentNode.multipleSelectors)
          if not parentNode.props.hasKey(node.ident):
            parentNode.props[node.ident] = node
          else:
            for k, v in node.props.pairs():
              parentNode.props[node.ident].props[k] = v
      else: return

proc parseSelector(p: var Parser, node: Node, tk: TokenTuple, scope: ScopeTable, toWalk = true): Node =
  if toWalk: walk p
  var multipleSelectors: seq[string]
  while p.curr.kind == TKComma:
    walk p
    if p.curr.kind notin {TKColon, TKIdentifier}:
      let prefixedIdent = prefixed(p.curr)
      if prefixedIdent != node.ident and prefixedIdent notin multipleSelectors:
        add multipleSelectors, prefixed(p.curr)
        walk p
      else:
        error(DuplicateSelector, p.curr, prefixedIdent)
  node.multipleSelectors = multipleSelectors
  
  # parse selector properties or child nodes
  if p.curr.line > tk.line:
    p.whileChild(tk, node, scope)
    result = node
    if unlikely(result.props.len == 0 and result.extends == false):
      warn(DeclaredEmptySelector, tk, true, node.ident)
  else:
    if not p.hasErrors: # to be sure will not be superseded
      error(UnexpectedToken, p.curr, p.curr.value)

template handleSelectorConcat(withConcat, withoutConcat: untyped) =
  if unlikely(p.next.kind == TKVarConcat and p.next.line == tk.line):
    walk p
    while p.curr.line == tk.line:
      # handle selector name + var concatenation
      case p.curr.kind
      of TKVarConcat:
        let concatVarCall = p.parseVariableCall(scope)
        if concatVarCall != nil:
          concatNodes.add(concatVarCall)
        else: return # UndeclaredVariable
      of TKIdentifier:
        concatNodes.add(newString(p.curr.value))
        walk p
      of TKRC:
        walk p
      of TKMinus:
        walk p # todo selector separators
      else:
        break
    withConcat
  else:
    withoutConcat
  p.ptrNodes[tk.value] = result

proc parseClass(p: var Parser, scope: ScopeTable = nil): Node =
  let tk = p.curr
  var concatNodes: seq[Node] # NTVariable
  handleSelectorConcat:
    p.currentSelector = tk.newClass(concat = concatNodes)
    result = p.parseSelector(p.currentSelector, tk, scope, toWalk = false)
  do:
    p.currentSelector = tk.newClass()
    result = p.parseSelector(p.currentSelector, tk, scope)
  p.ptrNodes[tk.value] = result

proc parseID(p: var Parser, scope: ScopeTable = nil): Node =
  let tk = p.curr
  result = p.parseSelector(tk.newID, tk, scope)

proc parseNest(p: var Parser, scope: ScopeTable = nil): Node =
  walk p
  case p.curr.kind
  of TKClass, TKID, TKPseudoClass:
    result = p.parseClass(scope)
    result.nested = true
  else:
    error(InvalidNestSelector, p.curr, p.curr.value)

proc parsePseudoNest(p: var Parser, scope: ScopeTable = nil): Node =
  if likely(pseudoTable.hasKey(p.next.value)):
    walk p
    p.curr.col = p.prev.col
    p.curr.pos = p.prev.pos
    let tk = p.curr
    result = p.parseSelector(tk.newPseudoClass, tk, scope)
  else:
    walk p
    error(UnknownPseudoClass, p.prev, p.curr.value)

proc parseVariableCall(p: var Parser, scope: ScopeTable = nil): Node = 
  if scope != nil:
    if scope.hasKey(p.curr.value):
      walk p
      return newCall(scope[p.prev.value])
  if likely(p.memtable.hasKey(p.curr.value)):
    let valNode = p.memtable[p.curr.value]
    valNode.markVarUsed()
    result = newCall(valNode)
    walk p
  else:
    error(UndeclaredVariable, p.curr, "$" & p.curr.value)

proc parseVariableAccessor(p: var Parser, scope: ScopeTable = nil): Node =
  var tkAccessor = p.curr.value.split(".")
  p.curr.value = tkAccessor[0]
  let varIdentStr = "$" & p.curr.value
  tkAccessor.delete(0)
  var key = tkAccessor[0]
  let node = p.parseVariableCall(scope)
  if node.callNode != nil:
    case node.callNode.varValue.nt
    of NTObject:
      if node.callNode.varValue.objectPairs.hasKey(key):
        result = newCall(node.callNode.varValue.objectPairs[key])
      else:
        error(UndefinedPropertyAccessor, p.curr, true, key, varIdentStr)
    of NTJsonValue:
      if node.callNode.varValue.jsonVal.hasKey(key):
        let jsonNode = newJson node.callNode.varValue.jsonVal[key]
        result = newCall(jsonNode)
      else:
        error(UndefinedPropertyAccessor, p.curr, true, key, varIdentStr)
    else:
      error(TryingAccessNonObject, p.curr, true, key, varIdentStr)

proc parseVariable(p: var Parser, scope: ScopeTable = nil): Node =
  ## Parse variable declaration
  let tk = p.curr
  var inArray, inObject: bool
  walk p # TKAssign
  case p.next.kind
  of TKLB:
    # Handle array values
    walk p # TKLB
    inArray = true
  of TKLC:
    # Handle object values
    walk p # TKLC
    inObject = true
  else: discard

  if likely(p.memtable.hasKey(tk.value) == false):
    case p.next.kind
    of tkAssignableValue:
      walk p
      var varNode, valNode: Node
      if p.curr.kind != TKVarCall:
        var varValue: string
        if likely(inArray == false and inObject == false):
          if p.curr.kind == TKBool:
            valNode = newValue(p.getAssignableNode(scope))
          else:
            while p.curr.line == tk.line: # todo check token kind
              if p.curr.kind == TKComment: break
              if p.curr.kind == TKVarCall:
                if p.memtable.hasKey(p.curr.value):
                  discard # todo
                else:
                  error(UndeclaredVariable, p.curr, "$" & p.curr.value)
                  return
              add varValue, spaces(p.curr.wsno)
              add varValue, p.curr.value
              walk p
            valNode = newValue(newString varValue.strip)
        elif inObject:
          # parse object key/value pairs
          valNode = newObject()
          while p.curr.kind == TKIdentifier and p.next.kind == TKColon:
            let key = p.curr.value
            if likely(valNode.objectPairs.hasKey(p.curr.value) == false):
              walk p # TKColon
              assert p.next.kind in tkAssignable
              walk p # any value from tkAssignable
              valNode.objectPairs[key] = newValue(p.getAssignableNode(scope))
              if p.curr.kind == TKComma:
                walk p
              elif p.curr.kind == TKIdentifier and p.curr.line == p.prev.line:
                error(InvalidIndentation, p.curr)
                return
            else:
              error(DuplicateObjectKey, p.curr)
              return
          if p.curr.kind == TKRC:
            walk p
          else:
            error(MissingClosingObjectBody, p.curr)
            return
        else:
          # parse array values
          valNode = newArray()
          while p.curr.kind != TKRB:
            valNode.arrayVal.add(newValue(p.getAssignableNode(scope)))
            if p.curr.kind == TKComma:
              walk p
          if p.curr.kind == TKRB:
            walk p
          else:
            error(MissingClosingBracketArray, p.curr)
            return
        varNode = newVariable(tk.value, valNode, tk)
      else: 
        if p.memtable.hasKey(p.curr.value):
          varNode = deepCopy p.memtable[p.curr.value]
        else:
          error(AssignUndeclaredVar, p.curr, "$" & p.curr.value)
      p.memtable[tk.value] = varNode
      return varNode
    of tkAssignableFn:
      walk p
      if p.next.kind == TKString:
        walk p
        try:
          # temporary
          let filePath = normalizedPath(p.filePath.parentDir / p.curr.value)
          let strContents = readFile(filePath)
          var varNode = newVariable(tk.value, newJson(parseJSON(strContents)), tk)
          p.memtable[tk.value] = varNode
          walk p
          return varNode
        except IOError:
          error(ConfigLoadingError, tk)
        except JsonParsingError as jsonError:
          error(InternalError, tk, true, "JSON parsing error: " & jsonError.msg)
        return
    else:
      error(UndefinedValueVariable, tk, "$" & tk.value)
  else:
    error(VariableRedefinition, p.curr)

proc inLoop(fpath: string, lastModified: Time): Parser =
  result = ^ spawn(partialThread(fpath, lastModified))
  # var lm = lastModified
  #   while true:
  #     let lastModifiedNow = fpath.getLastModificationTime()
  #     if p.hasErrors:
  #       if lastModifiedNow > lm:
  #         lm = lastModifiedNow
  #         p = inLoop(fpath, lm)
  #       sleep(220)
  #     else:
  #       return p
  # else:
  #   result = p

proc parseImport(p: var Parser, scope: ScopeTable = nil): Node = 
  if p.next.kind == TKString:
    walk p # walk to file name
  var fpath = addFileExt(p.curr.value, "sass").absolutePath
  if fileExists(fpath):
    var lastModified = fpath.getLastModificationTime()
    var pp = inLoop(fpath, lastModified)
    if pp.hasErrors:
      for error in pp.logger.errors:
        display(error)
      display(" 👉 " & pp.logger.filePath)
      return
    if pp.memtable.len != 0:
      for k, v in pp.memtable.pairs:
        if not p.memtable.hasKey(k):
          p.memtable[k] = v
        else:
          error(DuplicateVarDeclaration, p.curr, "$" & k)
          return
    result = newImport(pp.program.nodes, fpath)
    walk p
  else:
    error(ImportErrorFileNotFound, p.curr, p.curr.value)

proc getNil(p: var Parser): Node =
  result = nil
  walk p

proc parseFunctionStmt(p: var Parser, scope: ScopeTable = nil): Node =
  discard

proc parseFunctionCall(p: var Parser, scope: ScopeTable = nil): Node =
  discard

proc parseForStmt(p: var Parser, scope: ScopeTable = nil): Node =
  ## Parse `for x in y` loop statement
  var item: Node
  let tk = p.curr
  let tkNext = p.next
  item = newVariable(tkNext)
  walk p, 2
  if p.curr.kind == TKIn and p.next.kind in {TKVarCall, TKVarCallAccessor}:
    walk p # in
    var items = p.parse()
    if items == nil: return
    case p.curr.kind
    of TKColon:
      walk p
      if p.curr.line > tk.line and p.curr.col > tk.col:
        var forNode = newForStmt(item, items)
        if scope == nil:
          forNode.forScopes = ScopeTable()
        else:
          if not scope.hasKey(item.varName):
            forNode.forScopes = scope
          else:
            error(DuplicateVarDeclaration, tkNext)
        forNode.forScopes[item.varName] = item
        while p.curr.col > tk.col:
          if p.curr.kind == TK_EOF: break
          let forBodyNode = p.parse(forNode.forScopes)
          if forBodyNode != nil:
            forNode.forBody.add forBodyNode
          else: return
        return forNode
      error(InvalidIndentation, p.curr)
    else:
      error(UnexpectedToken, p.curr)
  else: error(InvalidSyntaxLoopStmt, p.curr)

proc getInfixOp(kind: TokenKind, isInfixInfix: bool): InfixOp =
  case kind:
  of TK_EQ: result = EQ
  of TK_NE: result = NE
  of TK_LT: result = LT
  of TK_LTE: result = LTE
  of TK_GT: result = GT
  of TK_GTE: result = GTE
  else:
    if isInfixInfix:
      case kind
      of TK_ANDAND, TKAltAnd:
        result = AND
      of TK_OR, TKAltOr:
        result = OR
      else: discard

proc parseInfixNode(p: var Parser, scope: ScopeTable, infixInfixNode: Node = nil): Node =
  if p.curr.kind in tkComparable or p.curr.isColor:
    let assignLeft = p.getAssignableNode(scope)
    assert assignLeft != nil # todo error msg
    var infixNode = newInfix(assignLeft)
    if p.curr.kind in tkOperators:
      infixNode.infixOp = getInfixOp(p.curr.kind, infixInfixNode != nil)
      walk p
      if p.curr.kind in tkComparable or p.curr.isColor:
        let assignRight = p.getAssignableNode(scope)
        assert assignRight != nil # todo error msg
        infixNode.infixRight = assignRight
        return infixNode
      else: error(InvalidInfixMissingValue, p.curr)
    else: error(InvalidInfixOperator, p.curr)
  else: error(InvalidInfixMissingValue, p.curr)

proc parseInfix(p: var Parser, scope: ScopeTable = nil): Node =
  result = p.parseInfixNode(scope)
  case p.curr.kind
  of TK_OR, TKAltOr, TKAndAnd, TKAltAnd:
    while p.curr.kind in {TK_OR, TKAltOr, TKAndAnd, TKAltAnd}:
      let logicalOp = getInfixOp(p.curr.kind, true)
      walk p
      result = newInfix(result, p.parseInfix(scope), logicalOp)
  else: discard

proc parseCondStmt(p: var Parser, scope: ScopeTable = nil): Node =
  ## Parse a conditional statement
  let tk = p.curr
  walk p
  let infixNode = p.parseInfix(scope)
  if infixNode != nil and p.curr.kind == TKColon:
    walk p
    result = newIf(infixNode)
    # Handle `if` statement
    while p.curr.col > tk.col and p.curr.kind != TKEOF:
      var subNode: Node
      case p.curr.kind
      of TKIdentifier:
        subNode = p.parseProperty(scope)
      else:
        subNode = p.parse(scope)
      if likely(subNode != nil):
        result.ifBody.add(subNode)
      else:
        return nil
    # Handle `elif` statements
    while p.curr.kind == TKElif:
      if p.curr.col == tk.col:
        walk p
        let infixElifNode = p.parseInfix(scope)
        if infixElifNode != nil and p.curr.kind == TKColon:
          walk p # :
          var elifBody: seq[Node]
          while p.curr.col > tk.col:
            if p.curr.kind == TKIdentifier:
              var propNode = p.parseProperty(scope)
              if likely(propNode != nil):
                elifBody.add propNode
              else: break
            else:
              var subNode = p.parse(scope)
              if likely(subNode != nil):
                elifBody.add subNode
              else: break
          result.elifNode.add (infixElifNode, elifBody)
      else:
        error(BadIndentation, p.curr)
        break
  else: error(InvalidSyntaxCondStmt, p.curr)

proc parseCaseStmt(p: var Parser, scope: ScopeTable = nil): Node =
  # Parse a `case` block statement
  let tk = p.curr # of
  walk p
  if p.curr.kind == TKVarCall:
    if p.next.kind == TKColon:
      let callNode = p.parseVariableCall(scope)
      result = newCaseStmt(callNode)
    walk p # :
    # handle one or more `of` statements
    if p.curr.kind == TKOF:
      var tkOf = p.curr
      while p.curr.kind == TKOF and p.curr.pos == tkOf.pos:
        tkOf = p.curr
        if p.next.kind in tkAssignableValue:
          walk p
          while p.curr.kind in tkAssignableValue and p.curr.kind != TKEOF:
            var caseCondTuple: CaseCondTuple
            caseCondTuple.condOf = p.getAssignableNode(scope)
            while p.curr.pos > tkOf.pos and p.curr.kind != TKEOF:
              var subNode: Node
              case p.curr.kind
              of TKIdentifier:
                subNode = p.parseProperty(scope)
              else:
                subNode = p.parse(scope)
              if subNode != nil:
                caseCondTuple.body.add(subNode)
              else: return
            result.caseCond.add caseCondTuple
            if caseCondTuple.body.len == 0:
              error(InvalidIndentation, p.curr)
              return
        else:
          error(InvalidValueCaseStmt, p.curr)
          return
      # handle `else` statement
      if p.curr.kind == TKElse:
        if p.curr.pos == tkOf.pos:
          let tkElse = p.curr
          walk p
          while p.curr.kind != TKEOF and p.curr.pos > tkElse.pos:
            var subNode: Node
            case p.curr.kind
            of TKIdentifier:
              subNode = p.parseProperty(scope)
            else:
              subNode = p.parse(scope)
            if subNode != nil:
              result.caseElse.add(subNode)
          if result.caseElse.len == 0:
            error(InvalidIndentation, p.curr)
    else: error(InvalidValueCaseStmt, p.curr)
  else: error(InvalidSyntaxCaseStmt, p.curr)

proc parsePreview(p: var Parser, scope: ScopeTable = nil): Node =
  result = newPreview(p.curr)
  walk p

proc parseTag(p: var Parser, scope: ScopeTable = nil): Node =
  let tk = p.curr
  result = p.parseSelector(tk.newTag, tk, scope)

proc getInfix(p: var Parser, kind: TokenKind): InfixFunction =
  discard
  # case p.curr.kind:
  # of TKPLus:
  # of TKMinus:

proc getPrefix(p: var Parser, kind: TokenKind): PrefixFunction =
  case p.curr.kind:
  # of TKRoot:
    # parseRoot
  of TKClass:
    parseClass
  of TKID:
    parseID
  of TKComment:
    parseComment
  of TKAnd:
    parseNest
  of TKPseudoClass:
    parsePseudoNest
  of TKVar:
    parseVariable
  of TKVarCall:
    parseVariableCall
  of TKVarCallAccessor:
    parseVariableAccessor
  of TKFunctionCall:
    parseFunctionCall
  of TKFunctionStmt:
    parseFunctionStmt
  of TKImport:
    parseImport
  of TKPreview:
    parsePreview
  of TKExtend:
    parseExtend
  of TKFor:
    parseForStmt
  of TKCase:
    parseCaseStmt
  of TKIdentifier:
    parseTag
  of TKIf:
    parseCondStmt
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
      error(UnrecognizedToken, p.curr)

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
    if result.curr.kind == TK_EOF: break
    let node = result.parse(excludeOnly = {TKExtend, TKPseudoClass})
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

proc partialThread(fpath: string, lastModified: Time): Parser {.thread.} =
  {.gcsafe.}:
    let lastTime = fpath.getLastModificationTime()
    result = Parser(ptype: Partial, filePath: fpath)
    initParser(fpath)

proc parseProgram*(fpath: string): Parser =
  ## Parse program and return `Parser` instance
  result = Parser(ptype: Main, filePath: fpath)
  result.projectDirectory = fpath.parentDir()
  initParser(fpath)

# proc parseProgram*(fpath: string): Parser =
#   var importer = resolve(fpath, fpath)
#   if not importer.hasError: 
#     result.lex = Lexer.init(importer.getFullCode)
#     result.program = Program()
#     result.memtable = Memtable()
#     result.curr = p.lex.getToken()
#     result.next = result.lex.getToken()
#     while not result.hasError:
#       if result.curr.kind == TK_EOF: break
#       let node = result.parse()
#       if likely(node != nil):
#         case node.nt
#         of NTVariable: discard
#         else: result.program.nodes.add(node)
#     result.lex.close()
#     for k, v in result.memtable.pairs():
#       if unlikely(v.varValue.used == false):
#         add result.warnings, ("$" & k, v.varMeta.line, v.varMeta.col)
#   else:
#     result.error = importer.getError()