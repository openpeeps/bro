# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import pkg/chroma
import std/[tables, hashes, strutils, json, sequtils]
import ./critbits

from ./tokens import TokenKind, TokenTuple

export critbits, chroma

when not defined release:
  import std/jsonutils
else:
  import pkg/jsony

type
  NodeType* = enum
    ntInvalid
    ntVoid = "void"
    ntRoot = "RootSelector"
    ntProperty = "CSSProperty"
    ntVariable = "variable"
    ntUniversalSelector = "*"
    ntAttrSelector = "AttributeSelector"
    ntClassSelector = "ClassSelector"
    ntPseudoSelector = "PseudoSelector"
    ntPseudoElements = "PseudoElement"
    ntIDSelector = "IDSelector"
    ntAtRule
    ntFunction = "function"
    ntMixin = "mix"
    ntComment = "Comment"
    ntDocBlock = "BlockComment"
    ntTagSelector
    ntString = "string"
    ntInt = "int"
    ntFloat = "float"
    ntBool = "bool"
    ntArray = "array"
    ntObject = "object"
    ntAccessor # $myarr[0] $myobj.field
    ntColor = "color"
    ntSize = "size"
    ntStream = "stream"
    ntDotExpr = "DotExpression"
    ntBracketExpr = "BracketExpression"
    ntAccQuoted = "QuotedString"
    ntIdent = "Identifier"
    ntCallFunction = "FunctionCall"
    ntCallRec
    ntInfixExpr = "InfixExpression"
    ntInfixMathExpr = "MathExpression"
    ntImport  = "MagicImport"
    ntPreview
    ntExtend  = "MagicExtend"
    ntForStmt = "LoopStatement"
    ntCondStmt = "CondStatement"
    ntCaseStmt = "CaseStatement"
    ntCommand = "Command"
    ntStmtList = "StatementList"
    ntInfo
    ntReturn = "ReturnCommand"
    ntAssign = "AssignCommand"

  PropertyRule* = enum
    propRuleNone
    propRuleDefault
    propRuleImportant

  KeyValueTable* = CritBitTree[Node]

  ColorType* = enum
    cNamed, cHex, cRGB, cRGBA, cRGBX,
    cHSLA, cCMY, cCMYK, cHSL, cHSV, cLAB,
    cLUV, cOklab, cPolarLab, cPolarLuv,
    cPolarOklab, cXYZ, cYUV, cColor

  GlobalValue* = enum
    gInherit = "inherit"
    gInitial = "initial"
    gRevert = "revert"
    gRevertLayer = "revert-layer"
    gUnset = "unset"

  InfixOp* {.pure.} = enum
    None
    EQ          = "=="
    NE          = "!="
    GT          = ">"
    GTE         = ">="
    LT          = "<"
    LTE         = "<="
    AND         = "and"
    OR          = "or"
    AMP         = "&"   # string concatenation

  Units* = enum
    # absolute lengths
    MM = "mm"
    CM = "cm"
    IN = "in"
    PX = "px"
    PT = "pt"
    PC = "pc"
    # relative lengths
    EM = "em"
    EX = "ex"
    CH = "ch"
    REM = "rem"
    VW = "vw"
    VH = "vh"
    VMIN = "vmin"
    VMAX = "vmax"
    PSIZE = "%"     # related to the parent size

  LengthType* = enum
    ltAbsolute
    ltRelative

  MathOp* {.pure.} = enum
    invalidCalcOp
    mPlus = "+"
    mMinus = "-"
    mMulti = "*"
    mDiv = "/"
    mMod = "%"

  CommandType* = enum
    cmdEcho
    cmdAssert
    cmdReturn

  ScopeTable* = TableRef[string, Node]

  CaseCondTuple* = tuple[caseOf: Node, body: Node]
  ConditionBranch* = tuple[expr, body: Node]

  Meta* = array[3, int]
  ParamDef* = (string, NodeType, Node)
  
  OptFlag* = enum
    optSkipIteration
    optSkipProperty
    optSkipSelector

  Node* {.acyclic.} = ref object
    case nt*: NodeType
    of ntProperty:
      pName*: string
      pVal*: seq[Node] # a seq of CSS values
      pRule*: PropertyRule
      pShared*: seq[Node] # a seq of CSS properties sharing the same value
    of ntFunction, ntMixin:
      fnIdent*, fnName*: string
      fnParams*: OrderedTable[string, ParamDef]
      fnBody*: Node          # ntStmtList
      fnReturnType*: NodeType
      fnUsed*, fnClosure*, fnFwdDecl*, fnExport*: bool
      fnSource*: string 
    of ntComment, ntDocBlock:
      comment*: string
    of ntVariable:
      varName*: string
      varValue*: Node
      varType*, varInitType*: NodeType
      varUsed*, varArg*, varImmutable*: bool
    of ntString:
      sVal*: string
    of ntInt:
      iVal*: int
    of ntFloat:
      fVal*: float
    of ntBool:
      bVal*: bool
    of ntColor:
      colorType: ColorType
      cValue*: Color
      colorGlobals: GlobalValue
      cVal*: string
    of ntArray:
      arrayType*: NodeType
      arrayItems*: seq[Node]
    of ntObject:
      pairsVal*: OrderedTableRef[string, Node]
      usedObject*: bool
    of ntAccessor:
      accessorStorage*: Node # Node of `ntArray` or `ntObject`
      accessorType*: NodeType # either `ntArray` or `ntObject`
      accessorKey*: Node # `ntString`, `ntInt` or `ntIdent` (type of `ntString`, `ntInt`)
    of ntAccQuoted:
      accVal*: string
      accVars*: seq[Node] # seq[ntVariable]
    of ntSize:
      sizeVal*: Node # Node of `ntInt` / `ntFloat`
      sizeUnit*: Units
      sizeType*: LengthType
    of ntStream:
      streamContent*: JsonNode
      usedStream*: bool
    of ntDotExpr:
      lhs*, rhs*: Node
    of ntBracketExpr:
      bracketLeft*, bracketIndex*: Node
    of ntIdent:
      # callOid*: string
      identName*: string
    of ntCallFunction:
      # stackOid*: Oid
      fnCallIdent*, fnCallIdentName*: string
      fnCallReturnType*: NodeType
      fnCallArgs*: seq[Node]
    of ntCallRec:
      recursiveCall*: Node # ntCallFunction
    of ntInfixExpr:
      infixOp*: InfixOp
      infixLeft*, infixRight*: Node
    of ntInfixMathExpr:
      mathInfixOp*: MathOp
      mathLeft*, mathRight*: Node
      mathResultType*: NodeType # either ntInt or ntFloat
      mathResult*: Node
    of ntCondStmt:
      # condOid*: Oid
      ifInfix*: Node
      ifStmt*: Node # ntStmtList
      elifStmt*: seq[tuple[comp: Node, body: Node]]
      elseStmt*: Node # ntStmtList
      condIfBranch*: ConditionBranch
      condElifBranch*: seq[ConditionBranch]
      condElseBranch*: Node # ntStmtList
    of ntCaseStmt:
      # caseOid*: Oid
      caseIdent*: Node # ntIdent
      caseCond*: seq[CaseCondTuple]
      caseElse*: Node # ntStmtList
    of ntImport:
      # modules*: seq[tuple[path: string, module: Stylesheet]]
      modules*: seq[string] # absolute path of imported stylesheets (one or more for comma separated imports)
    # of ntPreview:
    #   previewContent: string
    of ntExtend:
      extendIdent*: string
      extendProps*: KeyValueTable
    of ntForStmt:
      # forOid*: Oid
      loopItem*: (Node, Node) # key/value (objects) or key/nil (arrays)
      loopItems*: Node
      loopBody*: Node # ntStmtList
      forOptFlags*: OptFlag
    of ntTagSelector, ntClassSelector, ntPseudoSelector,
        ntIDSelector, ntUniversalSelector:
      ident*: string
      parents*: seq[string]
      multipleSelectors*: seq[string]
      nested*: bool
      properties*, pseudo*, innerNodes*: KeyValueTable
      extends*: bool
      extendFrom*, extendBy*: seq[string]
      identConcat*: seq[Node] # ntVariable
      selectorStmt*: Node # ntStmtList
    of ntCommand:
      cmdIdent*: CommandType 
      cmdValue*: Node
    of ntStmtList:
      stmtList*: seq[Node]
      stmtScope*: ScopeTable
      stmtTraces*: seq[string]
    of ntReturn:
      returnStmt*: Node
    of ntAssign:
      asgnIdent*: string
      asgnValue*: Node
    of ntInfo:
      nodeType*: NodeType
    else: discard
    meta*: Meta

  StylesheetType = enum
    styleTypeLocal
    styleTypeLibrary

  Stylesheet* = ref object
    # info*: tuple[version: string, createdAt: DateTime]
    sheetType*: StylesheetType
    nodes*: seq[Node]
    selectors*: CritBitTree[Node]
    exports*: ScopeTable
    sourcePath*: string
    meta*: Meta
      ## Count lines and columns when using Macros

  # Stylesheets* = StashTable[string, Stylesheet, 1000]
  Stylesheets* = Table[string, Stylesheet]

const
  cssSelectors* = {ntClassSelector, ntTagSelector, ntIDSelector,
                      ntRoot, ntUniversalSelector}

# proc getStack*(stylesheet: Stylesheet): ScopeTable = stylesheet.stack
# proc setGlobalScope*(stylesheet: Stylesheet, scope: ScopeTable) = stylesheet.stack = scope

# fwd declarations
proc newStream*(node: JsonNode): Node
proc newString*(sVal: string): Node

# proc newInt*(iVal: string): Node
proc newInt*(iVal: int): Node

# proc newFloat*(fVal: string): Node
proc newFloat*(fVal: float): Node

# proc newBool*(bVal: string): Node
proc newBool*(bVal: bool): Node

proc getNodeType*(node: Node): NodeType =
  result = node.nt # todo

# proc call*(node: Node, scope: ScopeTable): Node
# proc walkAccessorStorage*(node: Node, index: Node, scope: var seq[ScopeTable]): Node

proc `$`*(node: Node): string =
  {.gcsafe.}:
    when not defined release:
      pretty(toJson(node), 2)
    else:
      toJson(node)

proc `$`*(nodes: seq[Node]): string =
  {.gcsafe.}:
    when not defined release:
      pretty(toJson(nodes), 2)
    else:
      toJson(nodes)

proc `$`*(stylesheet: Stylesheet): string =
  {.gcsafe.}:
    when not defined release:
      pretty(toJson(stylesheet), 2)
    else:
      toJson(stylesheet)

proc prefixed*(tk: TokenTuple): string =
  result =
    case tk.kind
    of tkClass: "."
    of tkID: "#"
    of tkPseudo: ":"
    else: ""
  add result, tk.value

proc prefixSelector(node: Node): string =
  result =
    case node.nt
    of ntClassSelector: "." & node.ident
    of ntIDSelector: "#" & node.ident
    else: node.ident

proc getInfixOp*(kind: TokenKind, isInfixNest: bool): InfixOp =
  result =
    case kind:
    of tkEQ:  EQ
    of tkNE:  NE
    of tkLT:  LT
    of tkLTE: LTE
    of tkGT:  GT
    of tkGTE: GTE
    else:
      if isInfixNest:
        case kind
        of tkAnd: AND
        of tkOR:  OR
        else: None
      else: None

proc getInfixMathOp*(kind: TokenKind, isInfixInfix: bool): MathOp =
  result =
    case kind:
    of tkPlus: mPlus
    of tkMinus: mMinus
    of tkMultiply: mMulti
    of tkDivide: mDiv
    of tkMod: mMod
    else: invalidCalcOp

proc toString*(v: JsonNode): string =
  # Return a stringified version of JSON `v`
  case v.kind:
  of JString: v.str
  of JInt:    $(v.num)
  of JFloat:  $(v.fnum)
  of JObject,
     JArray: $(v)
  of JNull: "null"
  of JBool: $(v.bval)

proc toNode*(v: JsonNode): Node =
  case v.kind
  of JString: newString(v.str)
  of JInt:    newInt(v.num.int)
  of JFloat:  newFloat(v.fnum)
  of JObject, JArray: newStream(v)
  # of JNull: "null"
  of JBool: newBool(v.bval)
  else: nil

# proc walkObject*(tree: CritBitTree, index: Node, scope: var seq[ScopeTable]): Node =
#   case index.nt
#   of ntString:
#     result = tree[index.sVal]
#   # of ntIdent:
#     # result = tree[call(index, scope).sVal]
#   else: discard

# proc walkAccessorStorage*(node: Node, index: Node, scope: var seq[ScopeTable]): Node {.raises: IndexDefect.} =
#   # walk trough a Node tree using `index`
#   # todo catch IndexDefect
#   case node.nt:
#   of ntAccessor:
#     var x: Node
#     if node.accessorType == ntArray:
#       # handle an `ntArray` storage
#       x = walkAccessorStorage(node.accessorStorage, node.accessorKey, scope)
#       return walkAccessorStorage(x, index, scope)
#     # otherwise handle `ntObject` storage
#     x = walkAccessorStorage(node.accessorStorage, node.accessorKey, scope)
#     return walkAccessorStorage(x, index, scope)
#   of ntObject:
#     if index.nt == ntIdent:
#       return walkObject(node.pairsVal, index, scope)
#     result = node.pairsVal[index.sVal]
#   of ntArray:
#     if index.nt == ntIdent:
#       return node.arrayItems[call(index, scope).iVal]
#     result = node.arrayItems[index.iVal]
#   of ntVariable:
#     # echo scope.hasKey(node.varName)
#     return walkAccessorStorage(scope[node.varName].varValue, index, scope)
#   of ntStream:
#     case node.streamContent.kind:
#     of JObject:
#       if index.nt == ntIdent:
#         return toNode(node.streamContent[call(index, scope).sVal])
#       result = toNode(node.streamContent[index.sVal])
#     of JArray:
#       if index.nt == ntIdent:
#         return toNode(node.streamContent[call(index, scope).iVal])
#       result = toNode(node.streamContent[index.iVal])
#     else:
#       result = toNode(node.streamContent)
#   else: discard

proc trace*(stmtNode: Node, key: string) =
  add stmtNode.stmtTraces, key

proc cleanup*(stmtNode: Node) =
  for item in stmtNode.stmtTraces:
    stmtNode.stmtScope.del(item)
  setLen(stmtNode.stmtTraces, 0)

# proc cleanup*(stmtNode: Node, scope: ScopeTable) =
#   for item in stmtNode.stmtTraces:
#     stmtNode.stmtScope.del(item)
#   setLen(stmtNode.stmtTraces, 0)

proc cleanup*(stmtNode: Node, key: string) =
  stmtNode.cleanup()
  stmtNode.stmtScope.del(key)

proc getColor*(node: Node): string =
  result = node.cVal

proc getString*(node: Node): string =
  result = node.sVal

proc `$`(types: seq[NodeType]): string =
  let t = types.map(proc(x: NodeType): string = $(x))
  add result, "|" & t.join("|")

# proc identify*(ident: string, types: seq[NodeType]): string =
#   result = ident
#   var types =
#     types.map do:
#       proc(x: NodeType): string = $x
#   add result, "|" & join(types, "|")
#   # echo hash(result)

proc identify*(ident: string, types: seq[NodeType]): string =
  result = ident
  add result, "|" & $(types.len)
  # echo hash(result)

# API
proc trace(tk: TokenTuple): Meta = [tk.line, tk.pos, tk.col]

proc newNode*(nt: static NodeType): Node =
  ## Create a new `Node` of `nt`
  result = Node(nt: nt)

proc newNode*(nt: static NodeType, tk: TokenTuple): Node =
  ## Create a new `Node` of `nt`
  result = Node(nt: nt, meta: tk.trace)

proc newProperty*(pName: string): Node =
  ## Create a new ntProperty node
  result = Node(nt: ntProperty, pName: pName)

proc newString*(sVal: string): Node =
  ## Create a new ntString node
  result = Node(nt: ntString, sVal: sVal)

proc newString*(tk: TokenTuple): Node =
  ## Create a new ntString node
  result = Node(nt: ntString, sVal: tk.value, meta: tk.trace)

proc newAccQuoted*(str: string): Node =
  result = Node(nt: ntAccQuoted, accVal: str)

proc newInt*(iVal: string): Node =
  ## Create a new ntInt node
  result = Node(nt: ntInt, iVal: parseInt iVal)

proc newInt*(iVal: int): Node =
  ## Create a new ntInt node
  result = Node(nt: ntInt, iVal: iVal)

proc newInt*(tk: TokenTuple): Node =
  ## Create a new `int` node
  Node(nt: ntInt, iVal: parseInt(tk.value), meta: tk.trace)

proc newFloat*(fVal: string): Node =
  ## Create a new ntFloat node
  result = Node(nt: ntFloat, fVal: parseFloat fVal)

proc newFloat*(fVal: float): Node =
  ## Create a new ntFloat node
  result = Node(nt: ntFloat, fVal: fVal)

proc newFloat*(tk: TokenTuple): Node =
  ## Create a new `float` node
  Node(nt: ntFloat, fVal: parseFloat(tk.value), meta: tk.trace)

proc newBool*(bVal: bool): Node =
  ## Create a new ntbool node
  result = Node(nt: ntBool, bVal: bVal)

proc newBool*(tk: TokenTuple): Node =
  ## Create a new `bool` node
  Node(nt: ntBool, bVal: parseBool(tk.value), meta: tk.trace)

proc newColor*(cVal: string): Node =
  ## Create a new ntColor node
  result = Node(nt: ntColor, cVal: cVal)

proc newColor*(cVal: SomeColor): Node =
  Node(nt: ntColor, cValue: color(cVal))

proc newColor*(cVal: SomeColor, colorType: static ColorType): Node =
  Node(nt: ntColor, colorType: colorType, cValue: color(cVal))

proc newSize*(size: Node, unit: Units): Node =
  assert size.nt in {ntInt, ntFloat}
  let lt = case unit:
            of EM, EX, CH, REM, VW, VH, VMIN, VMAX, PSIZE: ltRelative
            else: ltAbsolute
  result = Node(nt: ntSize, sizeVal: size, sizeType: lt, sizeUnit: unit)

proc newSize*(f: float, unit: Units): Node =
  ## Create a new Size node of  type `ntFloat` followed by `unit`
  newSize(newFloat(f), unit)

proc newSize*(i: int, unit: Units): Node =
  ## Create a new Size node of type `ntInt` followed by `unit`
  newSize(newInt(i), unit)

# proc newInfo*(node: Node): Node = Node(nt: ntInfo, nodeType: node.getNodeType)

proc newStream*(src: string): Node =
  ## Create a new Stream node from YAML or JSON
  try:
    let str = readFile(src)
    when defined release:
      result = Node(nt: ntStream, streamContent: fromJson(str, JsonNode))
    else:
      result = Node(nt: ntStream, streamContent: parseJson(str))
  except IOError:
    echo "nope"
  except JsonParsingError:
    echo "internal error"

proc newStream*(node: JsonNode): Node =
  ## Create a new Stream from `node`
  Node(nt: ntStream, streamContent: node)

proc newObject*: Node =
  Node(nt: ntObject, pairsVal: newOrderedTable[string, Node]())

proc newArray*: Node =
  Node(nt: ntArray) ## Create a new ntArray node

proc newAccessor*(accType: NodeType, accStorage: Node): Node =
  ## Create a new accessor node
  assert accType in {ntArray, ntObject}
  assert accStorage.nt in {ntVariable, ntStream, ntAccessor, ntArray, ntObject} # a var type of array or anonymous arrays/objects
  # if accStorage.nt == ntVariable:
    # assert accStorage.varValue.nt in {ntArray, ntObject, ntStream}
  case accType:
  of ntArray:
    result = Node(nt: ntAccessor, accessorType: ntArray)
  of ntObject:
    result = Node(nt: ntAccessor, accessorType: ntObject)
  else: discard

proc newAssignment*(tk: TokenTuple, varValue: Node): Node =
  ## Create a new assignment node
  Node(nt: ntAssign, asgnIdent: tk.value, asgnValue: varValue, meta: tk.trace)

proc newCall*(tk: TokenTuple): Node =
  ## Create a new call node
  Node(nt: ntIdent, identName: tk.value, meta: tk.trace)

proc newCall*(id: TokenTuple, args: seq[Node], types: seq[NodeType]): Node =
  ## Create a new call node
  Node(nt: ntCallFunction, fnCallArgs: args, fnCallIdentName: id.value, fnCallIdent: identify(id.value, types), meta: id.trace)

proc newFnCall*[N: Node](returnType: NodeType, args: seq[N], ident, name: string): Node =
  Node(nt: ntCallFunction, fnCallArgs: args, fnCallIdent: ident,
        fnCallIdentName: name, fnCallReturnType: returnType)

const allowedInfixTokens = {ntColor, ntString, ntInt, ntSize,
                            ntBool, ntFloat, ntIdent, ntCallFunction,
                            ntInfixMathExpr, ntInfixExpr}

proc newInfix*(lhs, rhs: Node, infixOp: InfixOp, tk: TokenTuple): Node =
  ## Create a new infix node
  # assert lhs.nt in allowedInfixTokens
  # assert rhs.nt in allowedInfixTokens
  result = Node(nt: ntInfixExpr, infixLeft: lhs, infixRight: rhs, infixOp: infixOp, meta: tk.trace)

proc newInfix*(lhs: Node, tk: TokenTuple): Node =
  ## Create a new ntInfixExpr node
  # assert lhs.nt in allowedInfixTokens
  result = Node(nt: ntInfixExpr, infixLeft: lhs, meta: tk.trace)

proc newInfixCalc*(lhs: Node): Node =
  # assert lhs.nt in {ntInt, ntFloat, ntSize, ntIdent, ntCallFunction, ntInfixMathExpr}
  result = Node(nt: ntInfixMathExpr, mathLeft: lhs)

proc newInfixCalc*(lhs, rhs: Node, infixOp: MathOp): Node =
  # assert lhs.nt in {ntInt, ntFloat, ntSize, ntIdent, ntCallFunction, ntInfixExpr, ntInfixMathExpr}
  # assert rhs.nt in {ntInt, ntFloat, ntSize, ntIdent, ntCallFunction, ntInfixExpr, ntInfixMathExpr}
  result = Node(nt: ntInfixMathExpr, mathLeft: lhs, mathRight: rhs, mathInfixOp: infixOp)

proc newIf*(infix: Node): Node =
  ## Create a new `ntCondStmt` node
  # assert infix.nt in {ntInfixExpr, ntCallFunction, ntIdent}
  # case infix.nt:
  # of ntCallFunction, ntIdent:
  #   assert infix.getNodeType == ntBool
  # of ntInfixExpr: discard
  # else: doAssert false
  result = Node(nt: ntCondStmt, ifInfix: infix)

proc newImport*: Node =
  ## Create a new `ntImport` node
  result = Node(nt: ntImport)

# proc isImmutable(varName: string): bool =
#   for ch in varName[1..^1]:
#     if ch in {'-', '_', '0'..'9'}: continue
#     if not ch.isUpperAscii:
#       return false
#   result = true

proc newVariable*(varName: string, varValue: Node, tk: TokenTuple, isArg = false): Node =
  ## Create a new `ntVariable` (declaration) node
  result = Node(nt: ntVariable, varName: varName, varValue: varValue, varArg: isArg, meta: [tk.line, tk.pos, tk.col])

proc newVariable*(tk: TokenTuple): Node =
  ## Create a new `ntVariable` (declaration) node
  result = Node(nt: ntVariable, varName: tk.value, meta: [tk.line, tk.pos, tk.col])

proc newVariable*(id: string, varValue: Node): Node =
  ## Create a new variable
  Node(nt: ntVariable, varName: id, varValue: varValue)

proc newVariableRef*(tk: TokenTuple): Node =
  ## Create a new `ntVariable` reference
  result = Node(nt: ntVariable, varName: tk.value, meta: [tk.line, tk.pos, tk.col])

proc newComment*(str: string): Node = Node(nt: ntComment, comment: str)
proc newDocBlock*(str: string): Node = Node(nt: ntDocBlock, comment: str)

proc newTag*(tk: TokenTuple, properties = KeyValueTable(),
            concat: seq[Node] = @[]): Node =
  ## Create a new ntTag node
  Node(nt: ntTagSelector, ident: tk.prefixed,
    properties: properties, identConcat: concat)

proc newUniversalSelector*: Node = Node(nt: ntUniversalSelector, ident: $ntUniversalSelector)

proc newClass*(tk: TokenTuple, properties = KeyValueTable(),
            concat: seq[Node] = @[]): Node =
  ## Create a new ntClassSelector
  Node(nt: ntClassSelector, ident: tk.value,
    properties: properties, identConcat: concat)

proc newPseudoClass*(tk: TokenTuple, properties = KeyValueTable(),
            concat: seq[Node] = @[]): Node =
  ## Create a new ntPseudoSelector
  Node(nt: ntPseudoSelector, ident: tk.prefixed,
    properties: properties, identConcat: concat)

proc newID*(tk: TokenTuple, properties = KeyValueTable(),
            concat: seq[Node] = @[]): Node =
  ## Create a new ntIDSelector
  Node(nt: ntIDSelector, ident: tk.prefixed,
    properties: properties,  identConcat: concat)

proc newExtend*(tk: TokenTuple, keyValueTable: KeyValueTable): Node =
  ## Create a new ntExtend
  result = Node(nt: ntExtend, extendIdent: tk.value, extendProps: keyValueTable)

proc newForStmt*(item: (Node, Node), items: Node): Node =
  ## Create a new ntForStmt
  assert item[0].nt == ntVariable
  if item[1] != nil:
    assert item[1].nt == ntVariable
  result = Node(nt: ntForStmt, loopItem: item, loopItems: items)

proc newCaseStmt*(caseIdent: Node): Node =
  ## Create a new ntCaseStmt
  Node(nt: ntCaseStmt, caseIdent: caseIdent)

proc newFunction*(tk, fn: TokenTuple): Node =
  ## Create a new function (low-level API)
  Node(nt: ntFunction, fnName: tk.value, meta: [fn.line, fn.pos, fn.col])

proc newMixin*(tk, fn: TokenTuple): Node =
  ## Create a new mixin (low-level API)
  Node(nt: ntMixin, fnName: tk.value, meta: [fn.line, fn.pos, fn.col])

proc newFunction*(fnName: string): Node =
  ## Create a new function (low-level API)
  Node(nt: ntFunction, fnName: fnName)

proc newEcho*(val: Node, tk: TokenTuple): Node =
  ## Create a new `echo` command (low-level API)
  Node(nt: ntCommand, cmdIdent: cmdEcho, cmdValue: val, meta: tk.trace)

proc newAssert*(exp: Node, tk: TokenTuple): Node =
  Node(nt: ntCommand, cmdIdent: cmdAssert, cmdValue: exp, meta: tk.trace)

proc newReturn*(stmtNode: Node): Node =
  ## Create a new `return` statement
  Node(nt: ntReturn, returnStmt: stmtNode)

proc newStmt*(stmtScope: ScopeTable = nil): Node =
  result = Node(nt: ntStmtList)
  if stmtScope != nil:
    result.stmtScope = stmtScope
  else: new(result.stmtScope)