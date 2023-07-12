# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[tables, strutils, json, times, oids]
from ./tokens import TokenKind, TokenTuple

when not defined release:
  import std/jsonutils

type
  NodeType* = enum
    ntVoid
    ntRoot
    ntProperty
    ntVariable = "Variable"
    ntVarValue
    ntUniversalSelector
    ntAttrSelector
    ntClassSelector = "Class"
    ntPseudoClassSelector
    ntPseudoElements
    ntIDSelector
    ntAtRule
    ntFunction = "Function"
    ntComment
    ntTagSelector
    ntString = "String"
    ntInt = "Int"
    ntFloat = "Float"
    ntBool = "Bool"
    ntArray = "Array"
    ntObject = "Object"
    ntAccessor # $myarr[0] $myobj.field
    ntColor = "Color"
    ntSize = "Size"
    ntStream = "Stream"
    ntCall
    ntCallStack
    ntInfix
    ntImport
    ntPreview
    ntExtend
    ntForStmt
    ntCondStmt
    ntMathStmt
    ntCaseStmt
    ntCommand
    ntStmtList
    ntInfo
    ntReturn

  PropertyRule* = enum
    propRuleNone
    propRuleDefault
    propRuleImportant

  KeyValueTable* = OrderedTable[string, Node]

  ColorType* = enum
    cNamed, cHex, cRGB, cRGBA, cHSL, cHSLA

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
    Absolute
    Relative

  ArithmeticOperators* {.pure.} = enum
    Invalid
    Plus = "+"
    Minus = "-"
    Multi = "*"
    Div = "/"
    Modulo = "%"

  CommandType* = enum
    cmdEcho

  ScopeTable* = OrderedTableRef[string, Node]

  CaseCondTuple* = tuple[`of`: Node, body: Node]
  Meta* = tuple[line, pos: int]
  ParamDef* = (string, NodeType, Node)

  Node* = ref object
    case nt*: NodeType
    of ntProperty:
      pName*: string
      pVal*: seq[Node] # a seq of CSS values
      pRule*: PropertyRule
    of ntFunction:
      fnName*: string
      fnParams*: OrderedTable[string, ParamDef]
      fnBody*: Node          # ntStmtList
      fnReturnType*: NodeType
      fnUsed*: bool
      fnMeta*: Meta
    of ntComment:
      comment*: string
    of ntVariable:
      varName*: string
      varValue*: Node
      varMeta*: Meta 
      varUsed*: bool
    of ntVarValue:
      val*: Node
      used*: bool
    of ntString:
      sVal*: string
    of ntInt:
      iVal*: int
    of ntFloat:
      fVal*: float
    of ntBool:
      bVal*: bool
    of ntColor:
      colorType*: ColorType
      colorGlobals: GlobalValue
      cVal*: string
    of ntArray:
      itemsVal*: seq[Node]
    of ntObject:
      objectFields*: OrderedTable[string, Node]
      usedObject*: bool
    of ntAccessor:
      accessorType: NodeType # either ntArray or ntObject
    of ntSize:
      sizeVal*: int
      sizeUnit*: Units
      lenType*: LengthType
    of ntStream:
      streamContent*: JsonNode
      usedStream*: bool
    of ntCall:
      callIdent*: string
      callNode*: Node
    of ntCallStack:
      callStackIdent*: string
      callStackType*: NodeType
      callStackReturnType*: NodeType
      callStackArgs*: seq[Node]
    of ntInfix:
      infixOp*: InfixOp
      infixLeft*, infixRight*: Node
    of ntCondStmt:
      condOid*: Oid
      ifInfix*: Node
      ifStmt*: Node # ntStmtList
      elifStmt*: seq[tuple[comp: Node, body: Node]]
      elseStmt*: Node # ntStmtList

      # ifBody*: seq[Node]
      # elifNode*: seq[tuple[infix: Node, body: seq[Node]]]
      # elseBody*: seq[Node]
    of ntCaseStmt:
      caseOid*: Oid
      caseIdent*: Node # ntCall
      caseCond*: seq[CaseCondTuple]
      caseElse*: Node # ntStmtList
    of ntImport:
      importNodes*: seq[Node]
      importPath*: string
    of ntPreview:
      previewContent: string
    of ntExtend:
      extendIdent*: string
      extendProps*: KeyValueTable
    of ntForStmt:
      forOid*: Oid
      forItem*, inItems*: Node
      forBody*: Node # ntStmtList
      forScopes*: ScopeTable
        # Variable scopes Nodes of ntVarValue
    of ntMathStmt:
      mathInfixOp: ArithmeticOperators
      mathLeft, mathRight: Node
    of ntTagSelector, ntClassSelector, ntPseudoClassSelector, ntIDSelector:
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
      cmdMeta*: Meta
    of ntStmtList:
      stmtList*: seq[Node]
      stmtScope*: ScopeTable
    of ntReturn:
      returnStmt*: Node
    of ntInfo:
      nodeType*: NodeType
    else: discard
    aotStmts*: seq[Node]

  Program* = ref object
    # info*: tuple[version: string, createdAt: DateTime]
    nodes*: seq[Node]
    selectors*: Table[string, Node]
    stack*: ScopeTable

when not defined release:
  proc `$`*(node: Node): string =
    # print nodes while in dev mode
    result = pretty(toJson(node), 2)

proc prefixed*(tk: TokenTuple): string =
  result = case tk.kind
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

proc getInfixOp*(kind: TokenKind, isInfixInfix: bool): InfixOp =
  case kind:
  of tkEQ: result = EQ
  of tkNE: result = NE
  of tkLT: result = LT
  of tkLTE: result = LTE
  of tkGT: result = GT
  of tkGTE: result = GTE
  else:
    if isInfixInfix:
      case kind
      of tkANDAND, tkAndLit:
        result = AND
      of tkOR, tkOrLit:
        result = OR
      else: discard

proc call*(node: Node): Node = 
  result = node.callNode.varValue.val

proc use*(node: Node) =
  ## Mark a variable as used. If `node`
  ## is not a variable it does nothing.
  case node.nt:
  of ntVariable:
    node.varUsed = true
  of ntFunction:
    node.fnUsed = true 
  of ntCall:
    case node.callNode.nt:
    of ntVariable:
      node.callNode.varUsed = true
    else: discard
  else: discard

proc getColor*(node: Node): string =
  result = node.cVal

proc getString*(node: Node): string =
  result = node.sVal

proc getNodeType*(node: Node): NodeType =
  result =
    case node.nt
    of ntCall:
      case node.callNode.varValue.nt:
      of ntVarValue:
        node.callNode.varValue.val.nt
      else:
        node.callNode.varValue.nt
    of ntInfix: ntBool
    of ntMathStmt: ntInt # todo ntInt or ntFloat
    of ntArray, ntObject, ntBool, ntString, ntInt, ntFloat: node.nt   # anonymous array
    of ntFunction: ntFunction
    else:
      node.val.nt

# API

proc newProperty*(pName: string): Node =
  ## Create a new ntProperty node
  result = Node(nt: ntProperty, pName: pName)

proc newString*(sVal: string): Node =
  ## Create a new ntString node
  result = Node(nt: ntString, sVal: sVal)

proc newInt*(iVal: string): Node =
  ## Create a new ntInt node
  result = Node(nt: ntInt, iVal: parseInt iVal)

proc newFloat*(fVal: string): Node =
  ## Create a new ntFloat node
  result = Node(nt: ntFloat, fVal: parseFloat fVal)

proc newBool*(bVal: string): Node =
  ## Create a new ntbool node
  assert bVal in ["true", "false"]
  result = Node(nt: ntBool, bVal: parseBool bVal)

proc newColor*(cVal: string): Node =
  ## Create a new ntColor node
  result = Node(nt: ntColor, cVal: cVal)

proc newSize*(size: int, unit: Units): Node =
  let lt = case unit:
            of EM, EX, CH, REM, VW, VH, VMIN, VMAX, PSIZE: Relative
            else: Absolute
  result = Node(nt: ntSize, sizeVal: size, lenType: lt)

proc newInfo*(node: Node): Node =
  result = Node(nt: ntInfo, nodeType: node.getNodeType)

# proc newJson*(jsonVal: JsonNode): Node =
#   ## Create a new ntJsonValue node
#   result = Node(nt: ntJsonValue, jsonVal: jsonVal)

proc newStream*(src: string): Node =
  ## Create a new Stream node from YAML or JSON
  try:
    let str = readFile(src)
    result = Node(nt: ntStream, streamContent: parseJSON(str))
  except IOError:
    echo "nope"
  except JsonParsingError:
    echo "internal error"

proc newStream*(jsonNode: JsonNode): Node =
  ## Create a new Stream node from `jsonNode`
  result = Node(nt: ntStream, streamContent: jsonNode)

proc newObject*(): Node =
  ## Create a new ntObject node
  result = Node(nt: ntObject)

proc newArray*(): Node =
  ## Create a new ntArray node
  result = Node(nt: ntArray)

proc newCall*(ident: string, node: Node): Node =
  ## Create a new ntCall node
  # assert node.nt in {ntVariable, ntJsonValue}
  result = Node(nt: ntCall, callIdent: ident, callNode: node)

proc newFnCall*[N: Node](node: N, args: seq[N], ident: string): Node =
  result = Node(nt: ntCallStack, callStackArgs: args, callStackIdent: ident,
                callStackReturnType: node.fnReturnType)

proc newInfix*(infixLeft, infixRight: Node, infixOp: InfixOp): Node =
  ## Create a new ntInfix node
  assert infixLeft.nt in {ntColor, ntString, ntInt, ntBool, ntFloat, ntCall}
  assert infixRight.nt in {ntColor, ntString, ntInt, ntBool, ntFloat, ntCall}
  result = Node(nt: ntInfix, infixLeft: infixLeft, infixRight: infixRight, infixOp: infixOp)

proc newInfix*(infixLeft: Node): Node =
  ## Create a new ntInfix node
  assert infixLeft.nt in {ntColor, ntString, ntInt, ntBool, ntFloat, ntCall}
  result = Node(nt: ntInfix, infixLeft: infixLeft)

proc newIf*(infix: Node): Node =
  ## Create a new ntCondStmt
  assert infix.nt == ntInfix
  result = Node(nt: ntCondStmt, condOid: genOid(), ifInfix: infix)

proc newImport*(nodes: seq[Node], importPath: string): Node =
  ## Create a new ntImport node
  result = Node(nt: ntImport, importNodes: nodes, importPath: importPath)

proc newImport*(path: string): Node =
  ## Create a new ntImport node
  result = Node(nt: ntImport, importPath: path)

proc newVariable*(varName: string, varValue: Node, tk: TokenTuple): Node =
  ## Create a new ntVariable (declaration) node
  result = Node(nt: ntVariable, varName: varName, varValue: varValue, varMeta: (tk.line, tk.pos))

proc newVariable*(tk: TokenTuple): Node =
  ## Create a new ntVariable (declaration) node
  result = Node(nt: ntVariable, varName: tk.value, varMeta: (tk.line, tk.pos))

proc newValue*(val: Node): Node =
  ## Create a new ntVarValue node
  assert val.nt in {ntColor, ntString, ntInt, ntBool, ntFloat, ntCall}
  result = Node(nt: ntVarValue, val: val)

proc newValue*(tk: TokenTuple, valNode: Node): Node =
  ## Create a new ntVarValue node
  assert valNode.nt in {ntColor, ntString, ntInt, ntBool, ntFloat, ntCall}
  result = Node(nt: ntVarValue, val: valNode)

proc newComment*(str: string): Node =
  ## Create a new ntComment node
  result = Node(nt: ntComment, comment: str)

proc newTag*(tk: TokenTuple, properties = KeyValueTable(), multipleSelectors = @[""], concat: seq[Node] = @[]): Node =
  ## Create a new ntTag node
  Node(nt: ntTagSelector, ident: tk.prefixed, properties: properties, multipleSelectors: multipleSelectors, identConcat: concat)

proc newClass*(tk: TokenTuple, properties = KeyValueTable(), multipleSelectors = @[""], concat: seq[Node] = @[]): Node =
  ## Create a new ntClassSelector
  Node(nt: ntClassSelector, ident: tk.value, properties: properties, multipleSelectors: multipleSelectors, identConcat: concat)

proc newPseudoClass*(tk: TokenTuple, properties = KeyValueTable(), multipleSelectors = @[""], concat: seq[Node] = @[]): Node =
  ## Create a new ntPseudoClassSelector
  Node(nt: ntPseudoClassSelector, ident: tk.prefixed, properties: properties, multipleSelectors: multipleSelectors, identConcat: concat)

proc newID*(tk: TokenTuple, properties = KeyValueTable(), multipleSelectors = @[""], concat: seq[Node] = @[]): Node =
  ## Create a new ntIDSelector
  Node(nt: ntIDSelector, ident: tk.prefixed, properties: properties, multipleSelectors: multipleSelectors, identConcat: concat)

proc newPreview*(tk: TokenTuple): Node =
  ## Create a new ntPreview
  result = Node(nt: ntPreview, previewContent: tk.value)

proc newExtend*(tk: TokenTuple, keyValueTable: KeyValueTable): Node =
  ## Create a new ntExtend
  result = Node(nt: ntExtend, extendIdent: tk.value, extendProps: keyValueTable)

proc newForStmt*(item, items: Node): Node =
  ## Create a new ntForStmt
  result = Node(nt: ntForStmt, forOid: genOid(), forItem: item, inItems: items)

proc newCaseStmt*(caseIdent: Node): Node =
  ## Create a new ntCaseStmt
  result = Node(nt: ntCaseStmt, caseIdent: caseIdent)

proc newFunction*(tk: TokenTuple): Node =
  result = Node(nt: ntFunction, fnName: tk.value, fnMeta: (tk.line, tk.pos))

proc newEcho*(val: Node, tk: TokenTuple): Node =
  ## Create a new `echo` command
  result = Node(nt: ntCommand, cmdIdent: cmdEcho, cmdValue: val, cmdMeta: (tk.line, tk.pos))

proc newReturn*(stmtNode: Node): Node =
  ## Create a new `return` statement
  Node(nt: ntReturn, returnStmt: stmtNode)

proc newStmt*(stmtScope: ScopeTable = nil): Node =
  result = Node(nt: ntStmtList)
  if stmtScope != nil:
    result.stmtScope = stmtScope
  else: new(result.stmtScope)