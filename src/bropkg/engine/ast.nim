# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[tables, strutils, times, oids]
from ./tokens import TokenKind, TokenTuple

type
  NodeType* = enum
    NTRoot
    NTProperty
    NTVariable
    NTVariableValue
    NTUniversalSelector
    NTAttrSelector
    NTSelectorClass
    NTPseudoClass
    NTPseudoElements
    NTSelectorID
    NTAtRule
    NTFunction
    NTComment
    NTSelectorTag
    NTString
    NTInt
    NTFloat
    NTBool
    NTArray
    NTObject
    NTColor
    NTCall
    NTInfix
    NTImport
    NTPreview
    NTExtend
    NTForStmt
    NTCondStmt
    NTMathStmt
    NTCaseStmt

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

  ArithmeticOperators* {.pure.} = enum
    Invalid
    Plus = "+"
    Minus = "-"
    Multi = "*"
    Div = "/"
    Modulo = "%"

  # Value
  # VNodeType* = enum
  #   vntColor,
  #   vntPercentage

  # VNode* = ref object
  #   case vnt*: VNodeType
  #   of vntColor:
  #     colorValue: 
  #   of vntPercentage:

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
      iVal*: string
    of NTFloat:
      fVal*: string
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
    of NTSelectorTag, NTSelectorClass, NTPseudoClass, NTSelectorID:
      ident*: string
      parents*: seq[string]
      multipleSelectors*: seq[string]
      nested*, extends*: bool
      props*, pseudo*: KeyValueTable
      nodes*: seq[Node]
      identConcat*: seq[Node] # NTVariable
    else: discard
    parent*: Node # when nil is at root level

  Program* = ref object
    # info*: tuple[version: string, createdAt: DateTime]
    nodes*: seq[Node]

proc prefixed*(tk: TokenTuple): string =
  result = case tk.kind
            of TKClass: "."
            of TKID: "#"
            else: ""
  add result, tk.value

proc markVarUsed*(node: Node) =
  if node.varValue.nt == NTArray:
    node.varValue.usedArray = true
  else:
    node.varValue.used = true

proc newProperty*(pName: string): Node =
  result = Node(nt: NTProperty, pName: pName)

proc newString*(sVal: string): Node =
  result = Node(nt: NTString, sVal: sVal)

proc newInt*(iVal: string): Node =
  result = Node(nt: NTInt, iVal: iVal)

proc newFloat*(fVal: string): Node =
  result = Node(nt: NTFloat, fVal: fVal)

proc newBool*(bVal: string): Node =
  result = Node(nt: NTBool, bVal: parseBool bVal)

proc newColor*(cVal: string): Node =
  result = Node(nt: NTColor, cVal: cVal)

proc newObject*(): Node =
  result = Node(nt: NTObject)

proc newArray*(): Node =
  result = Node(nt: NTArray)

proc newCall*(node: Node): Node =
  result = Node(nt: NTCall, callNode: node)

proc newInfix*(infixLeft, infixRight: Node, infixOp: InfixOp): Node =
  result = Node(nt: NTInfix, infixLeft: infixLeft, infixRight: infixRight, infixOp: infixOp)

proc newInfix*(infixLeft: Node): Node =
  result = Node(nt: NTInfix, infixLeft: infixLeft)

proc newIf*(infix: Node): Node =
  result = Node(nt: NTCondStmt, condOid: genOid(), ifInfix: infix)

proc newImport*(nodes: seq[Node], importPath: string): Node =
  result = Node(nt: NTImport, importNodes: nodes, importPath: importPath)

proc newVariable*(varName: string, varValue: Node, tk: TokenTuple): Node =
  result = Node(nt: NTVariable, varName: varName, varValue: varValue, varMeta: (tk.line, tk.col))

proc newVariable*(tk: TokenTuple): Node =
  result = Node(nt: NTVariable, varName: tk.value, varMeta: (tk.line, tk.col))

proc newValue*(val: Node): Node =
  result = Node(nt: NTVariableValue, val: val)

proc newValue*(tk: TokenTuple, valNode: Node): Node =
  result = Node(nt: NTVariableValue, val: valNode)

proc newComment*(str: string): Node =
  result = Node(nt: NTComment, comment: str)

proc newTag*(tk: TokenTuple, string, props = KeyValueTable(), multipleSelectors = @[""]): Node =
  result = Node(nt: NTSelectorTag, ident: tk.prefixed, props: props, multipleSelectors: multipleSelectors)

# proc newRoot*(props: KeyValueTable = KeyValueTable()): Node =
#   result = Node(nt: NTRoot, ident: ":root", props: props)

proc newClass*(tk: TokenTuple, props = KeyValueTable(), multipleSelectors = @[""], concat: seq[Node] = @[]): Node =
  result = Node(nt: NTSelectorClass, ident: tk.prefixed,
              props: props, multipleSelectors: multipleSelectors, identConcat: concat)

proc newPseudoClass*(tk: TokenTuple, props = KeyValueTable(), multipleSelectors = @[""]): Node =
  result = Node(nt: NTPseudoClass, ident: tk.prefixed,
              props: props, multipleSelectors: multipleSelectors)

proc newID*(tk: TokenTuple, props = KeyValueTable()): Node =
  result = Node(nt: NTSelectorID, ident: tk.prefixed, props: props)

proc newPreview*(tk: TokenTuple): Node =
  result = Node(nt: NTPreview, previewContent: tk.value)

proc newExtend*(tk: TokenTuple, keyValueTable: KeyValueTable): Node =
  result = Node(nt: NTExtend, extendIdent: tk.value, extendProps: keyValueTable)

proc newForStmt*(item, items: Node): Node =
  ## Create a new `for` block statement
  result = Node(nt: NTForStmt, forOid: genOid(), forItem: item, inItems: items)

proc newCaseStmt*(caseIdent: Node): Node =
  ## Create a new `case` block statement
  result = Node(nt: NTCaseStmt, caseIdent: caseIdent)