# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[tables, critbits, strutils, times, oids]
from ./tokens import TokenKind, TokenTuple
from std/json import JsonNode

type
  NodeType* = enum
    NTRoot
    NTProperty
    NTVariable
    NTVariableValue
    NTUniversalSelector
    NTAttrSelector
    NTClassSelector
    NTPseudoClassSelector
    NTPseudoElements
    NTIDSelector
    NTAtRule
    NTFunction
    NTComment
    NTTagSelector
    NTString
    NTInt
    NTFloat
    NTBool
    NTArray
    NTObject
    NTAccessor # $myarr[0] $myobj.field
    NTColor
    NTSize
    NTJsonValue
    NTCall
    NTInfix
    NTImport
    NTPreview
    NTExtend
    NTForStmt
    NTCondStmt
    NTMathStmt
    NTCaseStmt
    NTCommand

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

  CaseCondTuple* = tuple[condOf: Node, body: seq[Node]]
  ScopeTable* = OrderedTableRef[string, Node]

  # Node
  Node* = ref object
    case nt*: NodeType
    of NTProperty:
      pName*: string
      pVal*: seq[Node]
      pRule*: PropertyRule
    of NTFunction:
      fnName: string
      fnParams: seq[Node]
    of NTComment:
      comment*: string
    of NTVariable:
      varName*: string
      varValue*: Node
      varMeta*: tuple[line, col: int]
    of NTVariableValue:
      val*: Node
      used*: bool
    of NTString:
      sVal*: string
    of NTInt:
      iVal*: int
    of NTFloat:
      fVal*: float
    of NTBool:
      bVal*: bool
    of NTColor:
      colorType*: ColorType
      colorGlobals: GlobalValue
      cVal*: string
    of NTArray:
      arrayVal*: seq[Node]
      usedArray*: bool
    of NTObject:
      objectPairs*: OrderedTable[string, Node]
      usedObject*: bool
    of NTAccessor:
      accessorType: NodeType # either NTArray or NTObject
    of NTSize:
      sizeVal*: int
      sizeUnit*: Units
      lenType*: LengthType
    of NTJsonValue:
      jsonVal*: JsonNode
      usedJson*: bool
    of NTCall:
      callNode*: Node
    of NTInfix:
      infixOp*: InfixOp
      infixLeft*, infixRight*: Node
    of NTCondStmt:
      condOid*: Oid
      ifInfix*: Node
      ifBody*: seq[Node]
      elifNode*: seq[tuple[infix: Node, body: seq[Node]]]
      elseBody*: seq[Node]
    of NTCaseStmt:
      caseOid*: Oid
      caseIdent*: Node # NTCall
      caseCond*: seq[CaseCondTuple]
      caseElse*: seq[Node] # body only
    of NTImport:
      importNodes*: seq[Node]
      importPath*: string
    of NTPreview:
      previewContent: string
    of NTExtend:
      extendIdent*: string
      extendProps*: KeyValueTable
    of NTForStmt:
      forOid*: Oid
      forItem*, inItems*: Node
      forBody*: seq[Node]
      forScopes*: ScopeTable
        # Variable scopes Nodes of NTVariableValue
    of NTMathStmt:
      mathInfixOp: ArithmeticOperators
      mathLeft, mathRight: Node
    of NTTagSelector, NTClassSelector, NTPseudoClassSelector, NTIDSelector:
      ident*: string
      parents*: seq[string]
      multipleSelectors*: seq[string]
      nested*: bool
      properties*, pseudo*, innerNodes*: KeyValueTable
      extends*: bool
      extendFrom*, extendBy*: seq[string]
      identConcat*: seq[Node] # NTVariable
    of NTCommand:
      cmdIdent*: CommandType 
      cmdValue*: Node
    else: discard
    aotStmts*: seq[Node]

  Program* = ref object
    # info*: tuple[version: string, createdAt: DateTime]
    nodes*: seq[Node]
    selectors*: Table[string, Node]

proc prefixed*(tk: TokenTuple): string =
  result = case tk.kind
            of tkClass: "."
            of tkID: "#"
            of tkPseudoClass: ":"
            else: ""
  add result, tk.value

proc prefixSelector(node: Node): string =
  result =
    case node.nt
    of NTClassSelector: "." & node.ident
    of NTIDSelector: "#" & node.ident
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
      of tkANDAND, tkAltAnd:
        result = AND
      of tkOR, tkAltOr:
        result = OR
      else: discard

proc markVarUsed*(node: Node) =
  case node.varValue.nt
  of NTArray:
    node.varValue.usedArray = true
  of NTObject:
    node.varValue.usedObject = true
  of NTJsonValue:
    node.varValue.usedJson = true
  else:
    node.varValue.used = true

proc call*(node: Node): Node = 
  result = node.callNode.varValue.val

proc getColor*(node: Node): string =
  result = node.cVal

proc getString*(node: Node): string =
  result = node.sVal

# API

proc newProperty*(pName: string): Node =
  ## Create a new NTProperty node
  result = Node(nt: NTProperty, pName: pName)

proc newString*(sVal: string): Node =
  ## Create a new NTString node
  result = Node(nt: NTString, sVal: sVal)

proc newInt*(iVal: string): Node =
  ## Create a new NTInt node
  result = Node(nt: NTInt, iVal: parseInt iVal)

proc newFloat*(fVal: string): Node =
  ## Create a new NTFloat node
  result = Node(nt: NTFloat, fVal: parseFloat fVal)

proc newBool*(bVal: string): Node =
  ## Create a new NTbool node
  assert bVal in ["true", "false"]
  result = Node(nt: NTBool, bVal: parseBool bVal)

proc newColor*(cVal: string): Node =
  ## Create a new NTColor node
  result = Node(nt: NTColor, cVal: cVal)

proc newSize*(size: int, unit: Units): Node =
  let lt = case unit:
            of EM, EX, CH, REM, VW, VH, VMIN, VMAX, PSIZE: Relative
            else: Absolute
  result = Node(nt: NTSize, sizeVal: size, lenType: lt)

proc newJson*(jsonVal: JsonNode): Node =
  ## Create a new NTJsonValue node
  result = Node(nt: NTJsonValue, jsonVal: jsonVal)

proc newObject*(): Node =
  ## Create a new NTObject node
  result = Node(nt: NTObject)

proc newArray*(): Node =
  ## Create a new NTArray node
  result = Node(nt: NTArray)

proc newCall*(node: Node): Node =
  ## Create a new NTCall node
  assert node.nt in {NTVariable, NTJsonValue}
  result = Node(nt: NTCall, callNode: node)

proc newInfix*(infixLeft, infixRight: Node, infixOp: InfixOp): Node =
  ## Create a new NTInfix node
  assert infixLeft.nt in {NTColor, NTString, NTInt, NTBool, NTFloat, NTCall}
  assert infixRight.nt in {NTColor, NTString, NTInt, NTBool, NTFloat, NTCall}
  result = Node(nt: NTInfix, infixLeft: infixLeft, infixRight: infixRight, infixOp: infixOp)

proc newInfix*(infixLeft: Node): Node =
  ## Create a new NTInfix node
  assert infixLeft.nt in {NTColor, NTString, NTInt, NTBool, NTFloat, NTCall}
  result = Node(nt: NTInfix, infixLeft: infixLeft)

proc newIf*(infix: Node): Node =
  ## Create a new NTCondStmt
  assert infix.nt == NTInfix
  result = Node(nt: NTCondStmt, condOid: genOid(), ifInfix: infix)

proc newImport*(nodes: seq[Node], importPath: string): Node =
  ## Create a new NTImport node
  result = Node(nt: NTImport, importNodes: nodes, importPath: importPath)

proc newImport*(path: string): Node =
  ## Create a new NTImport node
  result = Node(nt: NTImport, importPath: path)

proc newVariable*(varName: string, varValue: Node, tk: TokenTuple): Node =
  ## Create a new NTVariable (declaration) node
  result = Node(nt: NTVariable, varName: varName, varValue: varValue, varMeta: (tk.line, tk.col))

proc newVariable*(tk: TokenTuple): Node =
  ## Create a new NTVariable (declaration) node
  result = Node(nt: NTVariable, varName: tk.value, varMeta: (tk.line, tk.col))

proc newValue*(val: Node): Node =
  ## Create a new NTVariableValue node
  assert val.nt in {NTColor, NTString, NTInt, NTBool, NTFloat, NTCall}
  result = Node(nt: NTVariableValue, val: val)

proc newValue*(tk: TokenTuple, valNode: Node): Node =
  ## Create a new NTVariableValue node
  assert valNode.nt in {NTColor, NTString, NTInt, NTBool, NTFloat, NTCall}
  result = Node(nt: NTVariableValue, val: valNode)

proc newComment*(str: string): Node =
  ## Create a new NTComment node
  result = Node(nt: NTComment, comment: str)

proc newTag*(tk: TokenTuple, properties = KeyValueTable(), multipleSelectors = @[""], concat: seq[Node] = @[]): Node =
  ## Create a new NTTag node
  Node(nt: NTTagSelector, ident: tk.prefixed, properties: properties, multipleSelectors: multipleSelectors, identConcat: concat)

proc newClass*(tk: TokenTuple, properties = KeyValueTable(), multipleSelectors = @[""], concat: seq[Node] = @[]): Node =
  ## Create a new NTClassSelector
  Node(nt: NTClassSelector, ident: tk.value, properties: properties, multipleSelectors: multipleSelectors, identConcat: concat)

proc newPseudoClass*(tk: TokenTuple, properties = KeyValueTable(), multipleSelectors = @[""], concat: seq[Node] = @[]): Node =
  ## Create a new NTPseudoClassSelector
  Node(nt: NTPseudoClassSelector, ident: tk.prefixed, properties: properties, multipleSelectors: multipleSelectors, identConcat: concat)

proc newID*(tk: TokenTuple, properties = KeyValueTable(), multipleSelectors = @[""], concat: seq[Node] = @[]): Node =
  ## Create a new NTIDSelector
  Node(nt: NTIDSelector, ident: tk.prefixed, properties: properties, multipleSelectors: multipleSelectors, identConcat: concat)

proc newPreview*(tk: TokenTuple): Node =
  ## Create a new NTPreview
  result = Node(nt: NTPreview, previewContent: tk.value)

proc newExtend*(tk: TokenTuple, keyValueTable: KeyValueTable): Node =
  ## Create a new NTExtend
  result = Node(nt: NTExtend, extendIdent: tk.value, extendProps: keyValueTable)

proc newForStmt*(item, items: Node, toPairs = false): Node =
  ## Create a new NTForStmt
  result = Node(nt: NTForStmt, forOid: genOid(), forItem: item, inItems: items)

proc newCaseStmt*(caseIdent: Node): Node =
  ## Create a new NTCaseStmt
  result = Node(nt: NTCaseStmt, caseIdent: caseIdent)

proc newEcho*(cmdValue: Node): Node =
  result = Node(nt: NTCommand, cmdIdent: cmdEcho, cmdValue: cmdValue)
