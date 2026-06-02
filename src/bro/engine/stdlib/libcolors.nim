# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[strutils, options, base64]

import pkg/chroma
import pkg/vancode/interpreter/[chunk, ast, sym, value]

import ./inliner

const tyColor* = 20
proc initColors*(script: Script, systemModule: Module): Module = 
  ## Initialize the CSS colors module
  result = newModule("colors", some"std::colors")
  result.load(systemModule)
  
  script.addProc(result, "lighten", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let color = args[0].foreign(Color)
      initValue(tyColor, lighten(color, args[1].floatVal))
  )

  script.addProc(result, "darken", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let color = args[0].foreign(Color)
      initValue(tyColor, darken(color, args[1].floatVal))
  )

  script.addProc(result, "saturate", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let color = args[0].foreign(Color)
      initValue(tyColor, saturate(color, args[1].floatVal))
  )

  script.addProc(result, "desaturate", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let color = args[0].foreign(Color)
      initValue(tyColor, desaturate(color, args[1].floatVal))
  )

  script.addProc(result, "spin", @[paramDef("color", ttyColor), paramDef("degrees", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let color = args[0].foreign(Color)
      initValue(tyColor, spin(color, args[1].floatVal))
  )

  script.addProc(result, "mix", @[paramDef("a", ttyColor), paramDef("b", ttyColor)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let a = args[0].foreign(Color)
      let b = args[1].foreign(Color)
      initValue(tyColor, mix(a, b))
  )

  script.addProc(result, "mix", @[paramDef("a", ttyColor), paramDef("b", ttyColor), paramDef("v", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let a = args[0].foreign(Color)
      let b = args[1].foreign(Color)
      initValue(tyColor, mix(a, b, args[2].floatVal))
  )

  script.addProc(result, "mixCMYK", @[paramDef("a", ttyColor), paramDef("b", ttyColor)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let a = args[0].foreign(Color)
      let b = args[1].foreign(Color)
      initValue(tyColor, mixCMYK(a, b))
  )

  script.addProc(result, "toHex", @[paramDef("color", ttyColor)], ttyString,
    proc (args: StackView, argc: int): Value =
      let color = args[0].foreign(Color)
      initValue(toHex(color))
  )

  script.addProc(result, "toHexAlpha", @[paramDef("color", ttyColor)], ttyString,
    proc (args: StackView, argc: int): Value =
      let color = args[0].foreign(Color)
      initValue(toHexAlpha(color))
  )

  script.addProc(result, "toHtmlHex", @[paramDef("color", ttyColor)], ttyString,
    proc (args: StackView, argc: int): Value =
      let color = args[0].foreign(Color)
      initValue(toHtmlHex(color))
  )

  script.addProc(result, "parseHex", @[paramDef("hex", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, parseHex(args[0].stringVal[]))
  )

  script.addProc(result, "parseHexAlpha", @[paramDef("hex", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, parseHexAlpha(args[0].stringVal[]))
  )

  script.addProc(result, "parseHtmlHex", @[paramDef("hex", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, parseHtmlHex(args[0].stringVal[]))
  )

  script.addProc(result, "distance", @[paramDef("a", ttyColor), paramDef("b", ttyColor)], ttyFloat,
    proc (args: StackView, argc: int): Value =
      let a = args[0].foreign(Color)
      let b = args[1].foreign(Color)
      initValue(distance(a, b))
  )

  script.addProc(result, "almostEqual", @[paramDef("a", ttyColor), paramDef("b", ttyColor), paramDef("eps", ttyFloat, isOpt = true)], ttyBool,
    proc (args: StackView, argc: int): Value =
      let a = args[0].foreign(Color)
      let b = args[1].foreign(Color)
      let eps = if argc >= 3: args[2].floatVal else: 0.01.float32
      initValue(almostEqual(a, b, eps))
  )