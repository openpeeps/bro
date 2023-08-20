# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[macros, enumutils]
import ./critbits, ./ast

# std lib dependencies
import pkg/[jsony, nyml, chroma]
import std/[os, math, fenv, strutils, sequtils, random, unicode, json]

type
  Arg* = tuple[name: string, value: Node]
  NimCall* = proc(args: openarray[Arg], returnType: NodeType = ntVoid): Node

  Module = CritBitTree[NimCall]
  SourceCode* = distinct string

  Stdlib* = CritBitTree[(Module, SourceCode)]

  StringsModule* = object of CatchableError
  ArraysModule* = object of CatchableError
  OSModule* = object of CatchableError
  ColorsModule* = object of CatchableError
  SystemModule* = object of CatchableError

var stdlib* {.threadvar.}: Stdlib
var strutilsModule, sequtilsModule,
    osModule, critbitsModule, systemModule,
    mathModule, chromaModule {.threadvar.}: Module

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
      loadFrom: string

  proc addFunction(id: string, args: openarray[(NodeType, string)], nt: NodeType): string =
    var p = args.map do:
              proc(x: (NodeType, string)): string =
                "$1: $2" % [x[1], $(x[0])]          
    result = "fn $1*($2): $3\n" % [id, p.join(", "), $nt]

  proc fwd(id: string, returns: NodeType, args: openarray[(NodeType, string)] = [],
      alias = "", wrapper: NimNode = nil, loadFrom = ""): Forward =
    Forward(id: id, returns: returns, args: args.toSeq,
        alias: alias, wrapper: wrapper, hasWrapper: wrapper != nil,
        loadFrom: loadFrom)

  # proc `*`(nt: NodeType, count: int): seq[NodeType] =
  #   for i in countup(1, count):
  #     result.add(nt)

  proc argToSeq[T](arg: Arg): T =
    toNimSeq[string](arg.value)

  template formatWrapper: untyped =
    try:
      ast.newString(format(args[0].value.sVal, argToSeq[seq[string]](args[1])))
    except ValueError as e:
      raise newException(StringsModule, e.msg)

  template systemStreamFunction: untyped =
    try:
      let filepath =
        if not isAbsolute(args[0].value.sVal):
          absolutePath(args[0].value.sVal)
        else: args[0].value.sVal
      let str = readFile(args[0].value.sVal)
      let ext = filepath.splitFile.ext
      if ext == ".json":
        return ast.newStream(str.fromJson(JsonNode))
      elif ext in [".yml", ".yaml"]:
        return ast.newStream(yaml(str).toJson.get)
      else:
        echo "error"
    except IOError as e:
      raise newException(SystemModule, e.msg)
    except JsonParsingError as e:
      raise newException(SystemModule, e.msg)

  template systemRandomize: untyped =
    randomize()
    ast.newInt(rand(args[0].value.iVal))

  let
    fnSystem = @[
      fwd("json", ntStream, [(ntString, "path")], wrapper = getAst(systemStreamFunction())),
      fwd("yaml", ntStream, [(ntString, "path")], wrapper = getAst(systemStreamFunction())),
      fwd("rand", ntInt, [(ntInt, "max")], "random", wrapper = getAst(systemRandomize())),
      fwd("len", ntInt, [(ntString, "x")]),
      # fwd("inc", ntInt, [(ntMutInt, "x"), (ntInt, "y")], wrapper = getAst(systemInc()))
    ]

  let
    fnMath = @[
      fwd("ceil", ntFloat, [(ntFloat, "x")]),
      # fwd("clamp") need to add support for ranges
      fwd("floor", ntFloat, [(ntFloat, "x")]),
      fwd("max", ntInt, [(ntInt, "x"), (ntInt, "y")], loadFrom = "system"),
      fwd("min", ntInt, [(ntInt, "x"), (ntInt, "y")], loadFrom = "system"),
      fwd("round", ntFloat, [(ntFloat, "x")]),
      # fwd("abs", ntInt, [(ntInt, "x")]),
      fwd("hypot", ntFloat, [(ntFloat, "x"), (ntFloat, "y")]),
      fwd("log", ntFloat, [(ntFloat, "x"), (ntFloat, "base")]),
      fwd("pow", ntFloat, [(ntFloat, "x"), (ntFloat, "y")]),
      fwd("sqrt", ntFloat, [(ntFloat, "x")]),
      fwd("cos", ntFloat, [(ntFloat, "x")]),
      fwd("sin", ntFloat, [(ntFloat, "x")]),
      fwd("tan", ntFloat, [(ntFloat, "x")]),
      fwd("arccos", ntFloat, [(ntFloat, "x")], "acos"),
      fwd("arcsin", ntFloat, [(ntFloat, "x")], "asin"),
      fwd("radToDeg", ntFloat, [(ntFloat, "d")], "rad2deg"),
      fwd("degToRad", ntFloat, [(ntFloat, "d")], "deg2rad"),
      fwd("arctan", ntFloat, [(ntFloat, "x")], "atan"),
      fwd("arctan2", ntFloat, [(ntFloat, "x"), (ntFloat, "y")], "atan2"),
    ]
    # std/strings
    # implements common functions for working with strings
    # https://nim-lang.github.io/Nim/strutils.html
  let
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
      fwd("format", ntString, [(ntString, "s"), (ntArray, "a")], wrapper = getAst(formatWrapper()))
    ]

  # template colorsDesaturate: untyped =
  #   ast.newColor(chroma.desaturate(args[0].value.cNode.colorColor, args[1].value.fVal))
  
  proc size2Float(n: Node): float =
    if n.sizeVal.nt == ntInt:
      return toFloat(n.sizeVal.iVal) / 100
    return n.sizeVal.fVal / 100

  template colorLighten: untyped =
    let lightenColor = chroma.lighten(args[0].value.cValue, size2Float(args[1].value))
    ast.newColor(lightenColor)

  template colorDarken: untyped =
    let darkenColor = chroma.darken(args[0].value.cValue, size2Float(args[1].value))
    ast.newColor(darkenColor)

  template colorDesaturate: untyped =
    let desatColor = chroma.desaturate(args[0].value.cValue, size2Float(args[1].value))
    ast.newColor(desatColor)

  template colorSaturate: untyped =
    let satColor = chroma.saturate(args[0].value.cValue, size2Float(args[1].value))
    ast.newColor(satColor)

  template colorParse: untyped = 
    ast.newColor(chroma.parseHtmlColor(args[0].value.sVal))

  template color2Rgb: untyped =
    let rgbColor = rgb(uint8(args[0].value.iVal), uint8(args[1].value.iVal), uint8(args[2].value.iVal))
    ast.newColor(rgbColor, ColorType(cRGB))
  
  template color2Rgba: untyped =
    let rgbaColor = rgba(uint8(args[0].value.iVal), uint8(args[1].value.iVal), uint8(args[2].value.iVal), uint8(args[3].value.iVal))
    ast.newColor(rgbaColor, ColorType(cRGBA))

  template color2Hex: untyped =
    let hexColor = toHex(args[0].value.cValue)
    ast.newColor(hexColor.parseHex, ColorType(cHex))
  
  # template color2Rgb: untyped =
  #   let rgbColor = toHtmlRgb(args[0].value.cValue)
  #   ast.newColor(rgbColor.parseHex, ColorType(cHex))
  
  let
    fnColors = @[
      fwd("lighten", ntColor, [(ntColor, "x"), (ntSize, "amount")], wrapper = getAst colorLighten()),
      fwd("darken", ntColor, [(ntColor, "x"), (ntSize, "amount")], wrapper = getAst colorDarken()),
      fwd("saturate", ntColor, [(ntColor, "x"), (ntSize, "amount")], wrapper = getAst colorSaturate()),
      fwd("desaturate", ntColor, [(ntColor, "x"), (ntSize, "amount")], wrapper = getAst colorDesaturate()),
      # fwd("mix", ntColor, [(ntColor, "x"), (ntColor, "y")], wrapper = getAst(colorsLighten())),
      fwd("rgb", ntColor, [(ntInt, "red"), (ntInt, "green"), (ntInt, "blue")], wrapper = getAst(color2Rgb())),
      fwd("rgba", ntColor, [(ntInt, "red"), (ntInt, "green"), (ntInt, "blue"), (ntInt, "alpha")], wrapper = getAst(color2Rgba())),
      fwd("parseColor", ntColor, [(ntString, "x")], wrapper = getAst colorParse()),
      fwd("toHex", ntColor, [(ntColor, "x")], wrapper = getAst color2Hex()),
      # fwd("toRGB", ntColor, [(ntColor, "c")], wrapper = getAst color2Rgb()),
    ]

  # std/arrays
  # implements common functions for working with arrays (sequences)
  # https://nim-lang.github.io/Nim/sequtils.html
  
  template arraysContains: untyped =
    ast.newBool(system.contains(toNimSeq[string](args[0].value), args[1].value.sVal))

  template arraysAdd: untyped =
    add(args[0].value.arrayItems, args[1].value)

  template arraysShift: untyped =
    try:
      delete(args[0].value.arrayItems, 0)
    except IndexDefect as e:
      raise newException(ArraysModule, e.msg)

  template arraysPop: untyped =
    try:
      delete(args[0].value.arrayItems, args[0].value.arrayItems.high)
    except IndexDefect as e:
      raise newException(ArraysModule, e.msg)

  template arraysShuffle: untyped =
    randomize()
    shuffle(args[0].value.arrayItems)

  let
    fnArrays = @[
      fwd("contains", ntBool, [(ntArray, "x"), (ntString, "item")], wrapper = getAst arraysContains()),
      fwd("add", ntVoid, [(ntArray, "x"), (ntString, "item")], wrapper = getAst arraysAdd()),
      fwd("shift", ntVoid, [(ntArray, "x")], wrapper = getAst arraysShift()),
      fwd("pop", ntVoid, [(ntArray, "x")], wrapper = getAst arraysPop()),
      fwd("shuffle", ntVoid, [(ntArray, "x")], wrapper = getAst arraysShuffle()),
    ]
    # fnObjects = @[
    #   fwd("hasKey", ntBool, [ntObject, ntString]),
    #   # fwd("keys", ntArray, [ntObject])
    # ]


  # std/os
  # implements some read-only basic operating system functions
  # https://nim-lang.org/docs/os.html 
  template osWalkFiles: untyped =
    let x = toSeq(walkPattern(args[0].value.sVal))
    var a = ast.newArray()
    a.arrayType = ntString
    a.arrayItems =
      x.map do:
        proc(xpath: string): Node = ast.newString(xpath)
    a
  let
    fnOs = @[
      fwd("absolutePath", ntString, [(ntString, "path")], "absolute"),
      fwd("dirExists", ntBool, [(ntString, "path")]),
      fwd("fileExists", ntBool, [(ntString, "path")]),
      fwd("normalizedPath", ntString, [(ntString, "path")], "normalize"),
      # fwd("splitFile", ntTuple, [ntString]),
      fwd("extractFilename", ntString, [(ntString, "path")], "getFilename"),
      fwd("isAbsolute", ntBool, [(ntString, "path")]),
      fwd("isRelativeTo", ntBool, [(ntString, "path"), (ntString, "base")], "isRelative"),
      fwd("getCurrentDir", ntString),
      fwd("joinPath", ntString, [(ntString, "head"), (ntString, "tail")], "join"),
      fwd("parentDir", ntString, [(ntString, "path")]),
      fwd("walkFiles", ntArray, [(ntString, "path")], wrapper = getAst osWalkFiles()),
    ]

  result = newStmtList()
  let libs = [
    ("system", fnSystem, "system"),
    ("math", fnMath, "math"),
    ("strutils", fnStrings, "strings"),
    ("chroma", fnColors, "colors"),
    ("sequtils", fnArrays, "arrays"),
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
        of ntColor: "newColor"
        else: ""
      var i = 0
      var fnIdent = if fn.alias.len != 0: fn.alias else: fn.id
      add sourceCode, addFunction(fnIdent, fn.args, fn.returns)
      var callNode: NimNode
      if not fn.hasWrapper:
        var callableNode =
          if lib[0] != "system":
            if fn.loadFrom.len == 0:
              newCall(newDotExpr(ident(lib[0]), ident(fn.id)))
            else:
              newCall(newDotExpr(ident(fn.loadFrom), ident(fn.id)))
          else:
            newCall(ident(fn.id))
        for arg in fn.args:
          let fieldName =
            case arg[0]
            of ntBool: "bVal"
            of ntString: "sVal"
            of ntInt: "iVal"
            of ntFloat: "fVal"
            of ntArray: "arrayItems"
            of ntObject: "pairsVal"
            of ntColor: "cValue"
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
