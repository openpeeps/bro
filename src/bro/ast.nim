# Bro aka NimSass
# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro

import std/[tables]
from ./tokens import TokenKind, TokenTuple
# from std/enumutils import symbolName

# https://developer.mozilla.org/en-US/docs/Web/CSS/:root
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
    NTCall
    NTImport
    NTPreview
    NTExtend

  PropertyRule* = enum
    propRuleNone
    propRuleDefault
    propRuleImportant

  KeyValueTable* = OrderedTable[string, Node]

  # You ain't got no style, muthafucka
  # https://developer.mozilla.org/en-US/docs/Web/CSS/Attribute_selectors
  # https://developer.mozilla.org/en-US/docs/Web/CSS/Specificity
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
    of NTCall:
      callNode*: Node
    of NTImport:
      importNodes*: seq[Node]
      importPath*: string
    of NTPreview:
      previewContent: string
    of NTExtend:
      extendIdent*: string
      extendProps*: KeyValueTable
    else:
      ident*: string
      parents*: seq[string]
      multiIdent*: seq[string]
      nested*: bool
      props*, pseudo*: KeyValueTable

  Program* = ref object
    nodes*: seq[Node]

proc prefixed*(tk: TokenTuple): string =
  result = case tk.kind
            of TKClass: "."
            of TKID: "#"
            else: ""
  add result, tk.value

proc newProperty*(pName: string): Node =
  result = Node(nt: NTProperty, pName: pName)

proc newString*(sVal: string): Node =
  result = Node(nt: NTString, sVal: sVal)

proc newInt*(iVal: string): Node =
  result = Node(nt: NTInt, iVal: iVal)

proc newFloat*(fVal: string): Node =
  result = Node(nt: NTFloat, fVal: fVal)

proc newCall*(node: Node): Node =
  result = Node(nt: NTCall, callNode: node)

proc newImport*(nodes: seq[Node], importPath: string): Node =
  result = Node(nt: NTImport, importNodes: nodes, importPath: importPath)

proc newVariable*(varName: string, varValue: Node, tk: TokenTuple): Node =
  result = Node(nt: NTVariable, varName: varName, varValue: varValue, varMeta: (tk.line, tk.col))

proc newValue*(val: Node): Node =
  result = Node(nt: NTVariableValue, val: val)

proc newComment*(str: string): Node =
  result = Node(nt: NTComment, comment: str)

proc newTag*(tk: TokenTuple, string, props = KeyValueTable(), multiIdent = @[""]): Node =
  result = Node(nt: NTSelectorTag, ident: tk.prefixed, props: props, multiIdent: multiIdent)

proc newRoot*(props: KeyValueTable = KeyValueTable()): Node =
  result = Node(nt: NTRoot, ident: ":root", props: props)

proc newClass*(tk: TokenTuple, props = KeyValueTable(), multiIdent = @[""]): Node =
  result = Node(nt: NTSelectorClass, ident: tk.prefixed,
              props: props, multiIdent: multiIdent)

proc newPseudoClass*(tk: TokenTuple, props = KeyValueTable(), multiIdent = @[""]): Node =
  result = Node(nt: NTPseudoClass, ident: tk.prefixed,
              props: props, multiIdent: multiIdent)

proc newID*(tk: TokenTuple, props = KeyValueTable()): Node =
  result = Node(nt: NTSelectorID, ident: tk.prefixed, props: props)

proc newPreview*(tk: TokenTuple): Node =
  result = Node(nt: NTPreview, previewContent: tk.value)

proc newExtend*(tk: TokenTuple, keyValueTable: KeyValueTable): Node =
  result = Node(nt: NTExtend, extendIdent: tk.value, extendProps: keyValueTable)