# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/options
import pkg/chroma
import pkg/vancode/interpreter/[chunk, sym, value]

import ./inliner

const tyColor* = 20

proc resolveColor(v: Value): Color =
  case v.typeId
  of tyColor: v.foreign(Color)
  of tyString:
    let s = v.stringVal[]
    if s.len > 0 and s[0] == '#':
      let hex = s[1..^1]
      if hex.len == 3:
        # expand 3-char hex: #abc -> #aabbcc
        let expanded = "#" & hex[0] & hex[0] & hex[1] & hex[1] & hex[2] & hex[2]
        parseHtmlHex(expanded)
      elif hex.len == 4:
        # expand 4-char hex: #abcd -> #aabbccdd
        let expanded = "#" & hex[0] & hex[0] & hex[1] & hex[1] & hex[2] & hex[2] & hex[3] & hex[3]
        parseHexAlpha(expanded)
      elif hex.len == 6:
        parseHtmlHex(s)
      elif hex.len == 8:
        parseHexAlpha(s)
      else:
        Color(r: 0, g: 0, b: 0, a: 1)
    elif s.len == 6: parseHex(s)
    elif s.len == 8: parseHexAlpha(s)
    else: Color(r: 0, g: 0, b: 0, a: 1)
  else: Color(r: 0, g: 0, b: 0, a: 1)

proc initColors*(script: Script, systemModule: Module): Module =
  result = newModule("colors", some"std::colors")
  result.load(systemModule)
  result.add(genType(ttyColor, "ttyColor", true))

  # lighten
  script.addProc(result, "lighten", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, lighten(resolveColor(args[0]), args[1].floatVal)))
  script.addProc(result, "lighten", @[paramDef("color", ttyString), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, lighten(resolveColor(args[0]), args[1].floatVal)))

  # darken
  script.addProc(result, "darken", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, darken(resolveColor(args[0]), args[1].floatVal)))
  script.addProc(result, "darken", @[paramDef("color", ttyString), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, darken(resolveColor(args[0]), args[1].floatVal)))

  # saturate
  script.addProc(result, "saturate", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, saturate(resolveColor(args[0]), args[1].floatVal)))
  script.addProc(result, "saturate", @[paramDef("color", ttyString), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, saturate(resolveColor(args[0]), args[1].floatVal)))

  # desaturate
  script.addProc(result, "desaturate", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, desaturate(resolveColor(args[0]), args[1].floatVal)))
  script.addProc(result, "desaturate", @[paramDef("color", ttyString), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, desaturate(resolveColor(args[0]), args[1].floatVal)))

  # spin
  script.addProc(result, "spin", @[paramDef("color", ttyColor), paramDef("degrees", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, spin(resolveColor(args[0]), args[1].floatVal)))
  script.addProc(result, "spin", @[paramDef("color", ttyString), paramDef("degrees", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, spin(resolveColor(args[0]), args[1].floatVal)))

  # mix
  script.addProc(result, "mix", @[paramDef("a", ttyColor), paramDef("b", ttyColor)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, mix(resolveColor(args[0]), resolveColor(args[1]))))
  script.addProc(result, "mix", @[paramDef("a", ttyString), paramDef("b", ttyColor)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, mix(resolveColor(args[0]), resolveColor(args[1]))))
  script.addProc(result, "mix", @[paramDef("a", ttyColor), paramDef("b", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, mix(resolveColor(args[0]), resolveColor(args[1]))))
  script.addProc(result, "mix", @[paramDef("a", ttyString), paramDef("b", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, mix(resolveColor(args[0]), resolveColor(args[1]))))

  # mix with weight
  script.addProc(result, "mix", @[paramDef("a", ttyColor), paramDef("b", ttyColor), paramDef("v", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, mix(resolveColor(args[0]), resolveColor(args[1]), args[2].floatVal)))
  script.addProc(result, "mix", @[paramDef("a", ttyString), paramDef("b", ttyString), paramDef("v", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, mix(resolveColor(args[0]), resolveColor(args[1]), args[2].floatVal)))

  # mixCMYK
  script.addProc(result, "mixCMYK", @[paramDef("a", ttyColor), paramDef("b", ttyColor)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, mixCMYK(resolveColor(args[0]), resolveColor(args[1]))))
  script.addProc(result, "mixCMYK", @[paramDef("a", ttyString), paramDef("b", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, mixCMYK(resolveColor(args[0]), resolveColor(args[1]))))

  # toHex
  script.addProc(result, "toHex", @[paramDef("color", ttyColor)], ttyString,
    proc (args: StackView, argc: int): Value =
      initValue(toHex(resolveColor(args[0]))))
  script.addProc(result, "toHex", @[paramDef("color", ttyString)], ttyString,
    proc (args: StackView, argc: int): Value =
      initValue(toHex(resolveColor(args[0]))))

  # toHexAlpha
  script.addProc(result, "toHexAlpha", @[paramDef("color", ttyColor)], ttyString,
    proc (args: StackView, argc: int): Value =
      initValue(toHexAlpha(resolveColor(args[0]))))
  script.addProc(result, "toHexAlpha", @[paramDef("color", ttyString)], ttyString,
    proc (args: StackView, argc: int): Value =
      initValue(toHexAlpha(resolveColor(args[0]))))

  # toHtmlHex
  script.addProc(result, "toHtmlHex", @[paramDef("color", ttyColor)], ttyString,
    proc (args: StackView, argc: int): Value =
      initValue(toHtmlHex(resolveColor(args[0]))))
  script.addProc(result, "toHtmlHex", @[paramDef("color", ttyString)], ttyString,
    proc (args: StackView, argc: int): Value =
      initValue(toHtmlHex(resolveColor(args[0]))))

  # parseHex
  script.addProc(result, "parseHex", @[paramDef("hex", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, parseHex(args[0].stringVal[])))

  # parseHexAlpha
  script.addProc(result, "parseHexAlpha", @[paramDef("hex", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, parseHexAlpha(args[0].stringVal[])))

  # parseHtmlHex
  script.addProc(result, "parseHtmlHex", @[paramDef("hex", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      initValue(tyColor, parseHtmlHex(args[0].stringVal[])))

  # distance
  script.addProc(result, "distance", @[paramDef("a", ttyColor), paramDef("b", ttyColor)], ttyFloat,
    proc (args: StackView, argc: int): Value =
      initValue(distance(resolveColor(args[0]), resolveColor(args[1]))))
  script.addProc(result, "distance", @[paramDef("a", ttyString), paramDef("b", ttyString)], ttyFloat,
    proc (args: StackView, argc: int): Value =
      initValue(distance(resolveColor(args[0]), resolveColor(args[1]))))

  # almostEqual
  script.addProc(result, "almostEqual", @[paramDef("a", ttyColor), paramDef("b", ttyColor), paramDef("eps", ttyFloat, isOpt = true)], ttyBool,
    proc (args: StackView, argc: int): Value =
      let eps = if argc >= 3: args[2].floatVal else: 0.01.float32
      initValue(almostEqual(resolveColor(args[0]), resolveColor(args[1]), eps)))
  script.addProc(result, "almostEqual", @[paramDef("a", ttyString), paramDef("b", ttyString), paramDef("eps", ttyFloat, isOpt = true)], ttyBool,
    proc (args: StackView, argc: int): Value =
      let eps = if argc >= 3: args[2].floatVal else: 0.01.float32
      initValue(almostEqual(resolveColor(args[0]), resolveColor(args[1]), eps)))

  # echo/toString for Color
  script.addProc(result, "echo", @[paramDef("x", ttyColor)], ttyVoid,
    proc (args: StackView, argc: int): Value =
      echo resolveColor(args[0]).toHtmlHex())

  script.addProc(result, "toString", @[paramDef("x", ttyColor)], ttyString,
    proc (args: StackView, argc: int): Value =
      result = initValue(resolveColor(args[0]).toHtmlHex()))
