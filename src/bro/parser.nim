# Bro aka NimSass
# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro

import pkg/klymene/cli
import std/[threadpool, times]
import std/[os, strutils, sequtils, macros, tables,
            memfiles, critbits]

import ./tokens, ./ast, ./memtable, ./logging
import ./properties

when not defined release:
  import std/[json, jsonutils] 

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
    ptrNodes: Table[string, Node]
    case ptype: ParserType
    of Main:
      projectDirectory: string
    else: discard
    filePath: string

  ParserErrors* = enum
    InvalidIndentation = "Invalid indentation"
    UndeclaredVariable = "Undeclared variable"
    AssignUndeclaredVar = "Assigning an undeclared variable"
    MissingAssignmentToken = "Missing assignment token"
    UndeclaredCSSSelector = "Undeclared CSS selector"
    ExtendCssSelector = "CSS properties can only be extended from ID or CSS selectors."
    InvalidProperty = "Invalid CSS property"
    DuplicateVarDeclaration = "Duplicate variable declaration"
    UnexpectedToken = "Unexpected token"
    UndefinedValueVariable = "Undefined value for variable"
    DeclaredEmtpySelector = "Declared CSS selector $ has no properties"

  ScopeTable = OrderedTableRef[string, Node]
  PrefixFunction = proc(p: var Parser, scope: ScopeTable = nil): Node
  PartialChannel = tuple[status: string, program: Program]

# forward definition
proc getPrefix(p: var Parser, kind: TokenKind): PrefixFunction
proc parse(p: var Parser, scope: ScopeTable = nil): Node
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
  tkVars = {TKVariableCall, TKVariable}
  tkAssignable = {TKString, TKInteger, TKBool, TKColor} + tkVars
  tkComparable = tkAssignable
  tkOperators = {TK_EQ, TK_NE, TK_GT, TK_GTE, TK_LT, TK_LTE}
  tkConditional = {TKIf, TKElif, TKElse}
  tkNamedColors = ["aliceblue", "antiquewhite", "aqua", "aquamarine", "azure", "beige",
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
    "whitesmoke", "yellow", "yellowgreen"]

proc isColor(tk: TokenTuple): bool =
  result = tk.value in tkNamedColors

proc getAssignableNode(p: var Parser, scope: ScopeTable): Node =
  if p.curr.kind == TKColor:
    result = newColor p.curr.value
    walk p
  elif p.curr.kind == TKString:
    result = newString p.curr.value
    walk p
  elif p.curr.kind == TKInteger:
    result = newInt p.curr.value
    walk p
  elif p.curr.kind == TKBool:
    result = newBool p.curr.value
    walk p
  elif p.curr.kind == TKVariableCall:
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

proc parseProperty(p: var Parser, scope: ScopeTable = nil): Node =
  if likely(Properties.hasKey(p.curr.value)):
    let pName = p.curr
    walk p
    if p.curr.kind == TKColon:
      walk p
      result = newProperty(pName.value)
      while p.curr.line == pName.line:
        if p.curr.kind in {TKIdentifier, TKColor, TKString, TKCenter} + tkPropsName:
          let property = Properties[pName.value]
          let propValue = getVNode(p.curr)
          let checkValue = property.hasStrictValue(p.curr.value)
          if checkValue.exists:
            if checkValue.status in {Unimplemented, Deprecated, Obsolete, NonStandard}:
              warn("Use of $ is marked as $", p.curr, true,
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
        elif p.curr.kind == TKInteger:
          result.pVal.add newInt(p.curr.value)
          walk p
        elif p.curr.kind == TKFloat:
          result.pVal.add newFloat(p.curr.value)
          walk p
        elif p.curr.kind == TKVariableCall:
          let callNode = p.parseVariableCall(scope)
          if callNode != nil:
            result.pVal.add(deepCopy(callNode))
          else:
            walk p
            return
        else:
          break # TODO error
      if p.curr.kind == TKImportant:
        result.pRule = propRuleImportant
        walk p
      elif p.curr.kind == TKDefault:
        result.pRule = propRuleDefault
        walk p
    else:
      error($MissingAssignmentToken, p.curr)
  else:
    error($InvalidProperty, p.curr)

proc whileChild(p: var Parser, this: TokenTuple, parentNode: Node, scope: ScopeTable) =
  while p.isPropOf(this):
    let tk = p.curr
    let propNode = p.parseProperty(scope)
    if likely(propNode != nil):
      parentNode.props[propNode.pName] = propNode
    else: return
    if p.curr.pos == this.pos: break
  while p.childOf(this):
    let
      tk = p.curr
      node = p.parse(scope)
    if node != nil:
      if unlikely(node.nt == NTExtend):
        # Add extended properties to parent node
        if likely(parentNode.props.hasKey(node.extendIdent) == false):
          for extendKey, extendProp in node.extendProps.pairs():
            parentNode.props[extendKey] = extendProp
        else:
          error("Extending properties more than once is not allowed", p.prev, node.extendIdent)
        if p.curr.kind == TKIdentifier:
          while p.isPropOf(this):
            let tk = p.curr
            let propNode = p.parseProperty(scope)
            if likely(propNode != nil):
              parentNode.props[propNode.pName] = propNode
            else: return
            if p.curr.pos == this.pos: break
      elif node.nt == NTForStmt:
        discard
      else:
        node.parents = concat(@[parentNode.ident], parentNode.multiIdent)
        if not parentNode.props.hasKey(node.ident):
          parentNode.props[node.ident] = node
        else:
          for k, v in node.props.pairs():
            parentNode.props[node.ident].props[k] = v
    else: return
    if p.curr.pos == this.pos: break

proc parseSelector(p: var Parser, node: Node, tk: TokenTuple, scope: ScopeTable, toWalk = true): Node =
  if toWalk: walk p
  var multiIdent: seq[string]
  while p.curr.kind == TKComma:
    walk p
    if p.curr.kind notin {TKColon, TKIdentifier}:
      let prefixedIdent = prefixed(p.curr)
      if prefixedIdent != node.ident and prefixedIdent notin multiIdent:
        add multiIdent, prefixed(p.curr)
        walk p
      else:
        err("Duplicated CSS declaration", p.curr, prefixedIdent)
  node.multiIdent = multiIdent
  if p.curr.line > tk.line:
    p.whileChild(tk, node, scope)
    result = node
    if unlikely(result.props.len == 0):
      warn($DeclaredEmtpySelector, tk, true, node.ident)
  else: error($UnexpectedToken, p.curr, p.curr.value)

# proc parseRoot(p: var Parser, scope: ScopeTable = nil): Node =
#   let tk = p.curr
#   result = p.parseSelector(newRoot(), tk, scope)

proc parseClass(p: var Parser, scope: ScopeTable = nil): Node =
  let tk = p.curr
  if unlikely(p.next.kind == TKVarConcat and p.next.line == tk.line):
    walk p
    var concatNodes: seq[Node] # NTVariable
    while p.curr.line == tk.line:
      # handle selector name + var concatenation
      if p.curr.kind == TKVarConcat:
        concatNodes.add(p.parseVariableCall(scope))
      elif p.curr.kind == TKIdentifier:
        concatNodes.add(newString(p.curr.value))
        walk p
      elif p.curr.kind == TKRC:
        walk p
      elif p.curr.kind == TKMinus:
        walk p # todo selector separators
      else:
        break
    result = p.parseSelector(tk.newClass(concat = concatNodes), tk, scope, toWalk = false)
  else:
    result = p.parseSelector(tk.newClass, tk, scope)
  p.ptrNodes[tk.value] = result

proc parseID(p: var Parser, scope: ScopeTable = nil): Node =
  let tk = p.curr
  result = p.parseSelector(tk.newID, tk, scope)

proc parseNest(p: var Parser, scope: ScopeTable = nil): Node =
  walk p
  if p.curr.kind == TKClass:
    result = p.parseClass(scope)
    result.nested = true
  else:
    err "Invalid nest for given selector", p.curr, p.curr.value

proc parsePseudoNest(p: var Parser, scope: ScopeTable = nil): Node =
  if likely(pseudoTable.hasKey(p.next.value)):
    walk p
    p.curr.col = p.prev.col
    p.curr.pos = p.prev.pos
    let tk = p.curr
    result = p.parseSelector(tk.newPseudoClass, tk, scope)
  else:
    walk p
    error("Unknown pseudo-class", p.prev, p.curr.value)

proc parseVariableCall(p: var Parser, scope: ScopeTable = nil): Node = 
  if scope != nil:
    if scope.hasKey(p.curr.value):
      walk p
      return newCall scope[p.prev.value]
  if likely(p.memtable.hasKey(p.curr.value)):
    let valNode = p.memtable[p.curr.value]
    if valNode.varValue.nt != NTArray:
      valNode.varValue.used = true
    else:
      valNode.varValue.usedArray = true
    result = newCall(valNode)
    walk p
  else:
    error($UndeclaredVariable, p.curr, "$" & p.curr.value)

proc parseVariable(p: var Parser, scope: ScopeTable = nil): Node =
  let tk = p.curr
  var inArray: bool
  walk p # :
  if p.next.kind == TKLB:
    walk p
    inArray = true
  if likely(p.memtable.hasKey(tk.value) == false):
    if p.next.kind in {TKIdentifier, TKColor, TKString, TKFloat, TKInteger, TKBool, TKVariableCall}:
      walk p
      var varNode, valNode: Node
      if p.curr.kind != TKVariableCall:
        var varValue: string
        if not inArray:
          while p.curr.line == tk.line:
            if p.curr.kind == TKComment: break
            if p.curr.kind == TKVariableCall:
              if p.memtable.hasKey(p.curr.value):
                discard # todo
              else:
                error($UndeclaredVariable, p.curr, "$" & p.curr.value)
            add varValue, spaces(p.curr.wsno)
            add varValue, p.curr.value
            walk p
          valNode = newValue(newString varValue.strip)
        else:
          valNode = Node(nt: NTArray)
          while p.curr.kind != TKRB:
            valNode.arrayVal.add(newValue(p.getAssignableNode(scope)))
            if p.curr.kind == TKComma:
              walk p
          if p.curr.kind == TKRB:
            walk p
          else:
            error("Missing closing bracket", p.curr)
            return
        varNode = newVariable(tk.value, valNode, tk)
      else: 
        if p.memtable.hasKey(p.curr.value):
          varNode = deepCopy p.memtable[p.curr.value]
        else:
          error($AssignUndeclaredVar, p.curr, "$" & p.curr.value)
      p.memtable[tk.value] = varNode
      return varNode
    error("Undefined value for variable", tk, tk.value)
  else:
    if p.next.kind in {TKIdentifier, TKColor, TKString, TKFloat, TKInteger}: 
      walk p
      p.memtable[tk.value].varValue.val = newString(p.curr.value)
      result = p.memtable[tk.value]
      walk p
    elif p.next.kind == TKVariableCall:
      walk p
      let node = p.parseVariableCall()
      p.memtable[tk.value] = deepCopy node.callNode
    else:
      error($UndefinedValueVariable, tk, tk.value)

proc inLoop(fpath: string, lastModified: Time): Parser =
  var p = ^ spawn(partialThread(fpath, lastModified))
  var lm = lastModified
  if p.hasError:
    for row in p.error.rows:
      display(row)
    while true:
      let lastModifiedNow = fpath.getLastModificationTime()
      if p.hasError:
        if lastModifiedNow > lm:
          lm = lastModifiedNow
          p = inLoop(fpath, lm)
        sleep(220)
      else:
        return p
  else:
    result = p

proc parseImport(p: var Parser, scope: ScopeTable = nil): Node = 
  if p.next.kind == TKString:
    walk p # walk to file name
  var fpath = addFileExt(p.curr.value, "sass").absolutePath
  if fileExists(fpath):
    var lastModified = fpath.getLastModificationTime()
    var pp = inLoop(fpath, lastModified)
    result = newImport(pp.program.nodes, fpath)
    walk p
  else:
    error("Import error file not found", p.curr, p.curr.value)

proc parseExtend(p: var Parser, scope: ScopeTable = nil): Node =
  walk p 
  if p.curr.kind in {TKClass, TKID}:
    if p.ptrNodes.hasKey(p.curr.value):
      result = newExtend(p.curr, p.ptrNodes[p.curr.value].props)
      walk p
    else:
      error($UndeclaredCSSSelector, p.curr, p.curr.value)
  else:
    error($ExtendCssSelector, p.curr)

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
  if p.curr.kind == TKIn:
    walk p # in
    var items = p.parseVariableCall() # raise "UndeclaredVariable"
    if items == nil: return
    if p.curr.kind == TKColon:
      walk p
      if p.curr.line > tk.line and p.curr.col > tk.col:
        var forNode = newForStmt(item, items)
        if scope == nil:
          forNode.forScopes = newOrderedTable[string, Node]()
        else:
          if not scope.hasKey(item.varName):
            forNode.forScopes = scope
          else:
            error($DuplicateVarDeclaration, tkNext)
        forNode.forScopes[item.varName] = item
        while p.curr.col > tk.col:
          if p.curr.kind == TK_EOF: break
          let forBodyNode = p.parse(forNode.forScopes)
          if forBodyNode != nil:
            forNode.forBody.add forBodyNode
          else: return
        return forNode
      error($InvalidIndentation, p.curr)
    else:
      error("Unexpected token", p.curr)
  else: error("Invalid loop statement", p.curr)

proc getInfixOp(kind: TokenKind): InfixOp =
  case kind:
  of TK_EQ: result = EQ
  of TK_NE: result = NE
  of TK_LT: result = LT
  of TK_LTE: result = LTE
  of TK_GT: result = GT
  of TK_GTE: result = GTE
  of TK_AND: result = AND
  # of TK_AMP: result  = AMP
  else: discard

proc parseInfix(p: var Parser, scope: ScopeTable = nil): Node =
  if p.curr.kind in tkComparable or p.curr.isColor:
    let assignLeft = p.getAssignableNode(scope)
    assert assignLeft != nil
    var infixNode = newInfix(assignLeft)
    if p.curr.kind in tkOperators:
      infixNode.infixOp = getInfixOp p.curr.kind
      walk p
      if p.curr.kind in tkComparable or p.curr.isColor:
        let assignRight = p.getAssignableNode(scope)
        assert assignRight != nil 
        infixNode.infixRight = assignRight
        result = infixNode
      else: error("Invalid infix missing assignable token", p.curr)
    else: error("Invalid infix missing operator", p.curr)
  else: error("Invalid infix", p.curr)

proc parseCondStmt(p: var Parser, scope: ScopeTable = nil): Node =
  ## Parse a conditional statement
  let tk = p.curr
  walk p
  let infixNode = p.parseInfix(scope)
  if infixNode != nil and p.curr.kind == TKColon:
    walk p
    let ifNode = newIf(infixNode)
    while p.curr.col > tk.col:
      let subNode = p.parse(scope)
      if subNode != nil:
        ifNode.ifBody.add(subNode)
      else: return nil
    return ifNode
  error("Invalid conditional statement", p.curr)

proc parsePreview(p: var Parser, scope: ScopeTable = nil): Node =
  result = newPreview(p.curr)
  walk p

proc parseTag(p: var Parser, scope: ScopeTable = nil): Node =
  let tk = p.curr
  result = p.parseSelector(tk.newTag, tk, scope)

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
  of TKVariable:
    parseVariable
  of TKVariableCall:
    parseVariableCall
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
  of TKIdentifier:
    parseTag
  of TKIf:
    parseCondStmt
  else: nil

proc parse(p: var Parser, scope: ScopeTable = nil): Node =
  let callFunction = p.getPrefix(p.curr.kind)
  if callFunction != nil:
    let node = p.callFunction(scope)
    result = node
  else:
    error("Unrecognized token", p.curr)

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
  result.logger = Logger()
  while not result.hasError:
    if result.curr.kind == TK_EOF: break
    let node = result.parse()
    if likely(node != nil):
      result.program.nodes.add(node)
    else: break

  result.lex.close()
  for k, v in result.memtable.pairs():
    if v.varValue.nt != NTArray:
      if unlikely(v.varValue.used == false):
        result.logger.warn("Declared and not used", v.varMeta.line, v.varMeta.col, "$" & k)
    else:
      if unlikely(v.varValue.usedArray == false):
        result.logger.warn("Declared array and not used", v.varMeta.line, v.varMeta.col, "$" & k)

proc partialThread(fpath: string, lastModified: Time): Parser {.thread.} =
  {.gcsafe.}:
    let lastTime = fpath.getLastModificationTime()
    result = Parser(ptype: Partial, filePath: fpath)
    initParser(fpath)

proc parseProgram*(fpath: string): Parser =
  ## Parse program and return `Parser` instance
  result = Parser(ptype: Main)
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