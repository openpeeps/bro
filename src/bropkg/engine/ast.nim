# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[tables, strutils, critbits, json, sequtils, oids]
import ./stdlib
from ./tokens import TokenKind, TokenTuple

when not defined release:
  import std/jsonutils

type
  NodeType* = enum
    ntVoid = "void"
    ntRoot
    ntProperty
    ntVariable = "variable"
    ntUniversalSelector
    ntAttrSelector
    ntClassSelector = "class"
    ntPseudoSelector
    ntPseudoElements
    ntIDSelector
    ntAtRule
    ntFunction = "function"
    ntComment
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
    ntAccQuoted
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

  KeyValueTable* = CritBitTree[Node]

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

  ScopeTable* = TableRef[string, Node]

  CaseCondTuple* = tuple[`of`: Node, body: Node]
  Meta* = tuple[line, pos: int]
  ParamDef* = (string, NodeType, Node)

  Statement = object
    stmtList*: seq[Node]
    stmtScope*: ScopeTable
    stmtTraces*: seq[string]

  Node* {.acyclic.} = ref object
    case nt*: NodeType
    of ntProperty:
      pName*: string
      pVal*: seq[Node] # a seq of CSS values
      pRule*: PropertyRule
    of ntFunction:
      fnIdent*, fnName*: string
      fnParams*: CritBitTree[ParamDef]
      fnBody*: Node          # ntStmtList
      fnReturnType*: NodeType
      fnUsed*, fnClosure*, fnExport*: bool
      fnMeta*: Meta
    of ntComment:
      comment*: string
    of ntVariable:
      varName*: string
      varValue*: Node
      varMeta*: Meta 
      varUsed*, varArg*, varImmutable*, varMemoized*: bool
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
      pairsVal*: CritBitTree[Node]
      usedObject*: bool
    of ntAccessor:
      accessorStorage*: Node # Node of `ntArray` or `ntObject`
      accessorType*: NodeType # either `ntArray` or `ntObject`
      accessorKey*: string # a parseable `int` or string
    of ntAccQuoted:
      accVal*: string
      accVars*: seq[Node] # seq[ntVariable]
    of ntSize:
      sizeVal*: int
      sizeUnit*: Units
      sizeType*: LengthType
    of ntStream:
      streamContent*: JsonNode
      usedStream*: bool
    of ntCall:
      callOid*: Oid
      callIdent*: string
      callNode*: Node
    of ntCallStack:
      stackOid*: Oid
      stackIdent*, stackIdentName*: string
      stackType*: NodeType
      stackReturnType*: NodeType
      stackArgs*: seq[Node]
    of ntInfix:
      infixOp*: InfixOp
      infixLeft*, infixRight*: Node
    of ntMathStmt:
      mathInfixOp*: MathOp
      mathLeft*, mathRight*: Node
      mathResultType*: NodeType # either ntInt or ntFloat
      mathResult*: Node
    of ntCondStmt:
      condOid*: Oid
      ifInfix*: Node
      ifStmt*: Node # ntStmtList
      elifStmt*: seq[tuple[comp: Node, body: Node]]
      elseStmt*: Node # ntStmtList
    of ntCaseStmt:
      caseOid*: Oid
      caseIdent*: Node # ntCall
      caseCond*: seq[CaseCondTuple]
      caseElse*: Node # ntStmtList
    of ntImport:
      modules*: seq[tuple[path: string, module: Program]]
    of ntPreview:
      previewContent: string
    of ntExtend:
      extendIdent*: string
      extendProps*: KeyValueTable
    of ntForStmt:
      forOid*: Oid
      forItem*, inItems*: Node
      forBody*: Node # ntStmtList
      forStorage*: ScopeTable
    of ntTagSelector, ntClassSelector, ntPseudoSelector, ntIDSelector:
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
      stmtTraces*: seq[string]
    of ntReturn:
      returnStmt*: Node
    of ntInfo:
      nodeType*: NodeType
    else: discard
    aotStmts*: seq[Node]

  Program* = ref object
    # info*: tuple[version: string, createdAt: DateTime]
    nodes*: seq[Node]
    selectors*: CritBitTree[Node]
    stack*: ScopeTable
    sourcePath*: string
    meta: Meta
      ## Count lines and columns when using Macros

# fwd declarations
proc newStream*(node: JsonNode): Node
proc newString*(sVal: string): Node

proc newInt*(iVal: string): Node
proc newInt*(iVal: int): Node

proc newFloat*(fVal: string): Node
proc newFloat*(fVal: float): Node

proc newBool*(bVal: string): Node
proc newBool*(bVal: bool): Node

# proc newNull(): Node

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
  result =
    case kind:
    of tkEQ: EQ
    of tkNE: NE
    of tkLT: LT
    of tkLTE: LTE
    of tkGT: GT
    of tkGTE: GTE
    else:
      if isInfixInfix:
        case kind
        of tkANDAND, tkAndLit: AND
        of tkOR, tkOrLit: OR
        else: None
      else: None

proc getInfixCalcOp*(kind: TokenKind, isInfixInfix: bool): MathOp =
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

proc toNode(v: JsonNode): Node =
  case v.kind
  of JString: newString(v.str)
  of JInt:    newInt(v.num.int)
  of JFloat:  newFloat(v.fnum)
  of JObject,
     JArray: newStream(v)
  # of JNull: "null"
  of JBool: newBool(v.bval)
  else: nil

proc walkAccessorStorage*(node: Node, index: string, scope: ScopeTable): Node =
  # walk trough a Node tree using `index`
  # todo catch IndexDefect
  case node.nt:
  of ntAccessor:
    var x: Node
    if node.accessorType == ntArray:
      # handle an `ntArray` storage
      x = walkAccessorStorage(node.accessorStorage, node.accessorKey, scope)
      return walkAccessorStorage(x, index, scope)
    # otherwise handle `ntObject` storage
    x = walkAccessorStorage(node.accessorStorage, node.accessorKey, scope)
    return walkAccessorStorage(x, index, scope)
  of ntObject:
    result = node.pairsVal[index]
  of ntArray:
    result = node.itemsVal[parseInt(index)]
  of ntVariable:
    return walkAccessorStorage(node.varValue, index, scope)
    # result = node.varValue.itemsVal[parseInt(index)]
  of ntStream:
    case node.streamContent.kind:
    of JObject:
      result = toNode(node.streamContent[index])
    of JArray:
      result = toNode(node.streamContent[parseInt(index)])
    else:
      result = toNode(node.streamContent)
  else: discard

proc call*(node: Node, scope: ScopeTable): Node =
  if node.callNode != nil:
    return
      case node.callNode.nt
      of ntVariable:
        case node.callNode.varValue.nt # todo find a better way
        of ntMathStmt: node.callNode.varValue.mathResult
        else: node.callNode.varValue
      of ntAccessor:
        walkAccessorStorage(node.callNode.accessorStorage, node.callNode.accessorKey, scope)
      else: nil
  assert scope != nil
  result = scope[node.callIdent]

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

proc getNodeType*(node: Node): NodeType =
  result =
    case node.nt
    of ntCall:
      node.callNode.varValue.nt
    of ntInfix: ntBool
    of ntMathStmt: ntInt # todo ntInt or ntFloat
    of ntArray, ntObject, ntBool, ntString, ntInt, ntFloat: node.nt   # anonymous array
    of ntFunction: ntFunction
    else: node.nt

proc `$`(types: openarray[NodeType]): string =
  let t = types.map(proc(x: NodeType): string = $(x))
  add result, "|" & t.join("|")

proc identify*(ident: string, types: openarray[NodeType]): string =
  result = ident
  if types.len > 0:
    add result, $(types)

# API

proc newProperty*(pName: string): Node =
  ## Create a new ntProperty node
  result = Node(nt: ntProperty, pName: pName)

proc newString*(sVal: string): Node =
  ## Create a new ntString node
  result = Node(nt: ntString, sVal: sVal)

proc newAccQuoted*(str: string): Node =
  result = Node(nt: ntAccQuoted, accVal: str)

proc newInt*(iVal: string): Node =
  ## Create a new ntInt node
  result = Node(nt: ntInt, iVal: parseInt iVal)

proc newInt*(iVal: int): Node =
  ## Create a new ntInt node
  result = Node(nt: ntInt, iVal: iVal)

proc newFloat*(fVal: string): Node =
  ## Create a new ntFloat node
  result = Node(nt: ntFloat, fVal: parseFloat fVal)

proc newFloat*(fVal: float): Node =
  ## Create a new ntFloat node
  result = Node(nt: ntFloat, fVal: fVal)

proc newBool*(bVal: string): Node =
  ## Create a new ntbool node
  assert bVal in ["true", "false"]
  result = Node(nt: ntBool, bVal: parseBool bVal)

proc newBool*(bVal: bool): Node =
  ## Create a new ntbool node
  result = Node(nt: ntBool, bVal: bVal)

proc newColor*(cVal: string): Node =
  ## Create a new ntColor node
  result = Node(nt: ntColor, cVal: cVal) 

proc newSize*(size: int, unit: Units): Node =
  let lt = case unit:
            of EM, EX, CH, REM, VW, VH, VMIN, VMAX, PSIZE: ltRelative
            else: ltAbsolute
  result = Node(nt: ntSize, sizeVal: size, sizeType: lt)

proc newInfo*(node: Node): Node = Node(nt: ntInfo, nodeType: node.getNodeType)

proc newStream*(src: string): Node =
  ## Create a new Stream node from YAML or JSON
  try:
    let str = readFile(src)
    result = Node(nt: ntStream, streamContent: parseJSON(str))
  except IOError:
    echo "nope"
  except JsonParsingError:
    echo "internal error"

proc newStream*(node: JsonNode): Node =
  ## Create a new Stream from `node`
  Node(nt: ntStream, streamContent: node)

proc newObject*(): Node = Node(nt: ntObject) ## Create a new ntObject node
proc newArray*(): Node = Node(nt: ntArray) ## Create a new ntArray node

proc newAccessor*(accType: NodeType, accStorage: Node): Node =
  ## Create a new `ntAccessor` Node
  assert accType in {ntArray, ntObject}
  assert accStorage.nt in {ntVariable, ntStream, ntAccessor, ntArray, ntObject} # a var type of array or anonymous arrays/objects
  if accStorage.nt == ntVariable:
    assert accStorage.varValue.nt in {ntArray, ntObject, ntStream}
  case accType:
  of ntArray:
    result = Node(nt: ntAccessor, accessorType: ntArray, accessorStorage: accStorage)
  of ntObject:
    result = Node(nt: ntAccessor, accessorType: ntObject, accessorStorage: accStorage)
  else: discard

proc newCall*(id: string, node: Node): Node =
  ## Create a new ntCall node
  # assert node.nt in {ntVariable, ntJsonValue}
  Node(nt: ntCall, callIdent: id, callOid: genOid(), callNode: node)

proc newFnCall*[N: Node](node: N, args: seq[N], ident, name: string): Node =
  Node(nt: ntCallStack, stackArgs: args, stackOid: genOid(),
        stackIdent: ident, stackIdentName: name,
        stackReturnType: node.fnReturnType)

const allowedInfixTokens = {ntColor, ntString, ntInt,
                            ntBool, ntFloat, ntCall, ntCallStack}

proc newInfix*(infixLeft, infixRight: Node, infixOp: InfixOp): Node =
  ## Create a new ntInfix node
  assert infixLeft.nt in allowedInfixTokens
  assert infixRight.nt in allowedInfixTokens
  result = Node(nt: ntInfix, infixLeft: infixLeft, infixRight: infixRight, infixOp: infixOp)

proc newInfix*(infixLeft: Node): Node =
  ## Create a new ntInfix node
  assert infixLeft.nt in allowedInfixTokens
  result = Node(nt: ntInfix, infixLeft: infixLeft)

proc newInfixCalc*(infixLeft: Node): Node =
  assert infixLeft.nt in {ntInt, ntFloat, ntCall, ntCallStack}
  result = Node(nt: ntMathStmt, mathLeft: infixLeft)

proc newIf*(infix: Node): Node =
  ## Create a new `ntCondStmt`
  assert infix.nt in {ntInfix}
  result = Node(nt: ntCondStmt, condOid: genOid(), ifInfix: infix)

proc newImport*: Node =
  ## Create a new `ntImport` node
  result = Node(nt: ntImport)

proc newVariable*(varName: string, varValue: Node, tk: TokenTuple, isImmutable, isArg = false): Node =
  ## Create a new `ntVariable` (declaration) node
  result = Node(nt: ntVariable, varName: varName, varValue: varValue,
                varImmutable: isImmutable, varArg: isArg, varMeta: (tk.line, tk.pos))

proc newVariable*(tk: TokenTuple): Node =
  ## Create a new `ntVariable` (declaration) node
  result = Node(nt: ntVariable, varName: tk.value, varMeta: (tk.line, tk.pos))

proc newComment*(str: string): Node =
  ## Create a new ntComment node
  result = Node(nt: ntComment, comment: str)

proc newTag*(tk: TokenTuple, properties = KeyValueTable(), concat: seq[Node] = @[]): Node =
  ## Create a new ntTag node
  Node(nt: ntTagSelector, ident: tk.prefixed, properties: properties, identConcat: concat)

proc newClass*(tk: TokenTuple, properties = KeyValueTable(), concat: seq[Node] = @[]): Node =
  ## Create a new ntClassSelector
  Node(nt: ntClassSelector, ident: tk.value, properties: properties, identConcat: concat)

proc newPseudoClass*(tk: TokenTuple, properties = KeyValueTable(), concat: seq[Node] = @[]): Node =
  ## Create a new ntPseudoSelector
  Node(nt: ntPseudoSelector, ident: tk.prefixed, properties: properties, identConcat: concat)

proc newID*(tk: TokenTuple, properties = KeyValueTable(), concat: seq[Node] = @[]): Node =
  ## Create a new ntIDSelector
  Node(nt: ntIDSelector, ident: tk.prefixed, properties: properties,  identConcat: concat)

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
  ## Create a new function (low-level API)
  result = Node(nt: ntFunction, fnName: tk.value, fnMeta: (tk.line, tk.pos))

proc newEcho*(val: Node, tk: TokenTuple): Node =
  ## Create a new `echo` command (low-level API)
  result = Node(nt: ntCommand, cmdIdent: cmdEcho, cmdValue: val, cmdMeta: (tk.line, tk.pos))

proc newReturn*(stmtNode: Node): Node =
  ## Create a new `return` statement
  Node(nt: ntReturn, returnStmt: stmtNode)

proc newStmt*(stmtScope: ScopeTable = nil): Node =
  result = Node(nt: ntStmtList)
  if stmtScope != nil:
    result.stmtScope = stmtScope
  else: new(result.stmtScope)

#
# High Level API
#
proc newStylesheet*: Program = 
  new(result)
  result.meta = (0, 1)

proc add*(p: Program, node: Node) =
  ## Add a new `node` to `Stylesheet`
  assert node != nil
  case node.nt
  of ntCommand:
    node.cmdMeta.line = p.meta.line 
  of ntVariable:
    node.varMeta.line = p.meta.line
  of ntReturn:
    raiseAssert("Cannot call `return` command at root level")
  else: discard
  p.nodes.add(node)
  inc p.meta.line

proc newBool*(style: Program, bVal: bool) =
  ## Create a new ntbool node
  style.add Node(nt: ntBool, bVal: bVal) 

proc newClass*(name: string, properties = KeyValueTable(), multipleSelectors = @[""], concat: seq[Node] = @[]): Node =
  ## Create a new ntClassSelector node
  Node(nt: ntClassSelector, ident: name, properties: properties, multipleSelectors: multipleSelectors, identConcat: concat)

proc newProperty*(selector: Node, pName: string, pVal: seq[Node]) =
  ## Create a new ntProperty node
  selector.properties[pName] =
    Node(nt: ntProperty, pName: pName, pVal: pVal)

proc newEcho*(style: Program, val: Node) =
  ## Create a new `echo` (high-level API)
  assert val != nil, "Expect a node value. Got nil"
  assert val.nt in {ntString, ntInt}, "Got " & $(val.nt)
  style.add Node(nt: ntCommand, cmdIdent: cmdEcho, cmdValue: val)

proc newFunction*(style: Program, name: string) =
  ## Create a new function (high-level API)
  style.add Node(nt: ntFunction, fnName: name)

proc newTag*(name: string, properties = KeyValueTable(), concat: seq[Node] = @[]): Node =
  ## Create a new `ntTag` node
  Node(nt: ntTagSelector, ident: name, properties: properties, identConcat: concat)

proc newPseudoClass*(name: string, properties = KeyValueTable(), concat: seq[Node] = @[]): Node =
  ## Create a new `ntPseudoSelector` node
  Node(nt: ntPseudoSelector, ident: name, properties: properties, identConcat: concat)


proc newVariable*(style: Program, name: string, value: Node) =
  ## Create a new variable node
  style.add Node(nt: ntVariable, varName: name, varValue: value)

proc newVariable*(style: Program, name: string, value: string) =
  ## Create a new variable node
  style.add Node(nt: ntVariable, varName: name, varValue: newString(value))