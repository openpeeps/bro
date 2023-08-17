# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[macros, enumutils]
import ./critbits, ./ast

import std/[os, strutils, sequtils, unicode]

type
  Arg* = tuple[name: string, value: Node]
  NimCall* = proc(args: openarray[Arg], returnType: NodeType = ntVoid): Node

  Module = CritBitTree[NimCall]
  SourceCode* = distinct string

  Stdlib* = CritBitTree[(Module, SourceCode)]

var stdlib* {.threadvar.}: Stdlib
var strutilsModule, sequtilsModule,
    osModule, critbitsModule {.threadvar.}: Module

proc toNimSeq*[T](node: Node): seq[T] =
  for item in node.arrayItems:
    result.add(item.sVal)

macro initStdlib() =
  type
    Wrapper = proc(args: seq[Node]): Node {.nimcall.}
    
    FwdType = enum
      fwdProc
      fwdIterator

    Forward = object
      fwdType: FwdType
      id: string
        # function identifier (nim side)
      alias: string
        # if not provided, it will use the `id`
        # for the bass function name
      returns: NodeType
        # the return type, one of: `ntString`, `ntInt`,
        # `ntBool`, `ntFloat`, `ntArray`, `ntObject`
      args: seq[(NodeType, string)]
        # a seq of NodeType for type matching
      wrapper: NimNode
        # wraps nim function
      hasWrapper: bool

  proc addFunction(id: string, args: openarray[(NodeType, string)], nt: NodeType): string =
    var p = args.map do:
              proc(x: (NodeType, string)): string =
                "$1: $2" % [x[1], $(x[0])]          
    result = "fn $1*($2): $3\n" % [id, p.join(", "), $nt]

  proc fwd(id: string, returns: NodeType,
      args: openarray[(NodeType, string)] = [], alias = ""): Forward =
    Forward(id: id, returns: returns, args: args.toSeq, alias: alias)

  proc fwd(id: string, returns: NodeType,
      args: openarray[(NodeType, string)] = [], wrapper: NimNode, alias = ""): Forward {.compileTime.} =
    Forward(id: id, returns: returns, args: args.toSeq, alias: alias, wrapper: wrapper, hasWrapper: true)

  proc `*`(nt: NodeType, count: int): seq[NodeType] =
    for i in countup(1, count):
      result.add(nt)

  proc argToSeq[T](arg: Arg): T =
    toNimSeq[string](arg.value)

  template formatWrapper: untyped =
    newString(format(args[0].value.sVal, argToSeq[seq[string]](args[1])))

  template seqStrContains: untyped =
    newBool(contains(args[0].value.sVal, args[0].value.sVal))

  let
    # std/strings
    # implements common functions for working with strings
    # https://nim-lang.github.io/Nim/strutils.html
    fnStrings = @[
      fwd("endsWith", ntBool, [(ntString, "s"), (ntString, "suffix")]),
      fwd("startsWith", ntBool, [(ntString, "s"), (ntString, "prefix")]),
      fwd("capitalizeAscii", ntString, [(ntString, "s")], "capitalize"),
      fwd("replace", ntString, [(ntString, "s"), (ntString, "sub"), (ntString, "by")]),
      fwd("toLowerAscii", ntString, [(ntString, "s")], "toLower"),
      fwd("contains", ntBool, [(ntString, "s"), (ntString, "sub")]),
      fwd("parseBool", ntBool, [(ntString, "s")], "toBool"),
      fwd("parseInt", ntInt, [(ntString, "s")], "toInt"),
      fwd("parseFloat", ntFloat, [(ntString, "s")], "toFloat"),
      fwd("format", ntString, [(ntString, "s"), (ntArray, "a")], getAst(formatWrapper()))
    ]
    # std/arrays
    # implements common functions for working with arrays (sequences)
    # https://nim-lang.github.io/Nim/sequtils.html
    # fnArrays = @[
    #   fwd("contains", ntBool, [ntArray, ntString], getAst(seqStrContains())),
    # ]
    # fnObjects = @[
    #   fwd("hasKey", ntBool, [ntObject, ntString]),
    #   # fwd("keys", ntArray, [ntObject])
    # ]
    # std/os
    # implements some read-only basic operating system functions
    # https://nim-lang.org/docs/os.html 
    fnOs = @[
      fwd("absolutePath", ntString, [(ntString, "path")], "absolute"),
      fwd("dirExists", ntBool, [(ntString, "path")]),
      fwd("fileExists", ntBool, [(ntString, "path")]),
      fwd("normalizedPath", ntString, [(ntString, "path")], "normalize"),
      # fwd("splitFile", ntTuple, [ntString]),
      fwd("extractFilename", ntString, [(ntString, "path")], "getFilename"),
      fwd("isAbsolute", ntBool, [(ntString, "path")]),
      fwd("isRelativeTo", ntBool, [(ntString, "path"), (ntString, "path")], "isRelative"),
      fwd("getCurrentDir", ntString),
      fwd("joinPath", ntString, [(ntString, "path"), (ntString, "path")], "join"),
      fwd("parentDir", ntString, [(ntString, "path")]),
    ]
  result = newStmtList()
  let libs = [
    ("strutils", fnStrings, "strings"),
    # ("sequtils", fnArrays, "arrays"),
    # ("critbits", fnObjects, "objects"),
    ("os", fnOs, "os")
  ]
  for lib in libs:
    var sourceCode: string
    for fn in lib[1]:
      var
        lambda = nnkLambda.newTree(newEmptyNode(), newEmptyNode(), newEmptyNode())
        params = newNimNode(nnkFormalParams)
      params.add(
        ident("Node"),
        nnkIdentDefs.newTree(
          ident("args"),
          nnkBracketExpr.newTree(
            ident("openarray"),
            ident("Arg")
          ),
          newEmptyNode()
        ),
        nnkIdentDefs.newTree(
          ident("returnType"),
          ident("NodeType"),
          ident(symbolName(fn.returns))
        )
      )
      lambda.add(params)
      lambda.add(newEmptyNode())
      lambda.add(newEmptyNode())
      var valNode = 
        case fn.returns:
        of ntBool: "newBool"
        of ntString: "newString"
        of ntInt: "newInt"
        of ntFloat: "newFloat"
        of ntArray: "newArray" # todo implement toArray
        of ntObject: "newObject" # todo implement toObject
        else: "None"
      var i = 0
      var fnIdent = if fn.alias.len != 0: fn.alias else: fn.id
      add sourceCode, addFunction(fnIdent, fn.args, fn.returns)
      var callNode: NimNode
      if not fn.hasWrapper:
        var callableNode =
          newCall(
            newDotExpr(
              ident(lib[0]),
              ident(fn.id)
            )
          )
        for arg in fn.args:
          let fieldName =
            case arg[0]
            of ntBool: "bVal"
            of ntString: "sVal"
            of ntInt: "iVal"
            of ntFloat: "fVal"
            of ntArray: "arrayItems"
            of ntObject: "pairsVal"
            else: "None"
          callableNode.add(
            newDotExpr(
              newDotExpr(
                nnkBracketExpr.newTree(
                  ident("args"),
                  newLit(i)
                ),
                ident("value")
              ),
              ident(fieldName)
            )
          )
          inc i
        callNode = newCall(ident(valNode), callableNode)
      else:
        callNode = fn.wrapper
      lambda.add(newStmtList(callNode))
      add result,
        newAssignment(
          nnkBracketExpr.newTree(
            ident(lib[0] & "Module"),
            newLit(fnIdent)
          ),
          lambda
        )
    add result,
      newAssignment(
        nnkBracketExpr.newTree(
          ident("stdlib"),
          newLit("std/" & lib[2])
        ),
        nnkTupleConstr.newTree(
          ident(lib[0] & "Module"),
          newCall(ident("SourceCode"), newLit(sourceCode))
        )
      )
    # echo sourceCode
  # echo result.repr

initStdlib()

proc exists*(lib: string): bool =
  ## Checks if if `lib` exists in `Stdlib` 
  result = stdlib.hasKey(lib)

proc std*(lib: string): (Module, SourceCode) {.raises: KeyError.} =
  ## Retrieves a module from `Stdlib`
  result = stdlib[lib]

proc call*(module: Module, fnName: string, args: seq[Arg]): Node =
  ## Retrieves a Nim proc from `module`
  result = module[fnName](args)
