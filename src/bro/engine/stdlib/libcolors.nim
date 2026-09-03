# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/options
import pkg/openparser/colors
import pkg/vancode/interpreter/[chunk, sym, value]

import ./inliner
import ./cssvalues

const tyColor* = 20

proc toPercent(amount: float): float {.inline.} =
  if amount > 0.0 and amount < 1.0: amount * 100.0 else: amount

proc toWeight(weight: float): float {.inline.} =
  if weight > 0.0 and weight < 1.0: weight * 100.0 else: weight

proc newBroColor*(col: Color, raw: string = ""): Value =
  let r = if raw.len > 0: raw else: col.toHtmlHex()
  # Display spelling cached on the foreign tag so the VM can emit colors
  # without bro imports (vancode scope only sees Value/ForeignData).
  result = initCssPayload(tyColor, BroColor(c: col, raw: r), r)

proc resolveColor*(v: Value): Color =
  if v.typeId != tyColor:
    raise newException(ValueError, "type mismatch: expected color, got typeId " & $v.typeId)
  v.foreign(BroColor).c

proc resolveBroColor*(v: Value): BroColor =
  if v.typeId != tyColor:
    raise newException(ValueError, "type mismatch: expected color, got typeId " & $v.typeId)
  v.foreign(BroColor)

proc broColorToString*(v: Value): string =
  resolveBroColor(v).raw

proc initColors*(script: Script, systemModule: Module): Module =
  result = newModule("colors", some"std::colors")
  result.load(systemModule)
  result.add(genType(ttyColor, "ttyColor", true))

  # lighten - strict color only (float + int amount overloads)
  script.addProc(result, "lighten", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(lighten(resolveColor(args[0]), toPercent(args[1].floatVal))))
  script.addProc(result, "lighten", @[paramDef("color", ttyColor), paramDef("amount", ttyInt)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(lighten(resolveColor(args[0]), toPercent(float(args[1].intVal)))))

  # darken
  script.addProc(result, "darken", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(darken(resolveColor(args[0]), toPercent(args[1].floatVal))))
  script.addProc(result, "darken", @[paramDef("color", ttyColor), paramDef("amount", ttyInt)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(darken(resolveColor(args[0]), toPercent(float(args[1].intVal)))))

  # saturate
  script.addProc(result, "saturate", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(saturate(resolveColor(args[0]), toPercent(args[1].floatVal))))
  script.addProc(result, "saturate", @[paramDef("color", ttyColor), paramDef("amount", ttyInt)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(saturate(resolveColor(args[0]), toPercent(float(args[1].intVal)))))

  # desaturate
  script.addProc(result, "desaturate", @[paramDef("color", ttyColor), paramDef("amount", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(desaturate(resolveColor(args[0]), toPercent(args[1].floatVal))))
  script.addProc(result, "desaturate", @[paramDef("color", ttyColor), paramDef("amount", ttyInt)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(desaturate(resolveColor(args[0]), toPercent(float(args[1].intVal)))))

  # spin
  script.addProc(result, "spin", @[paramDef("color", ttyColor), paramDef("degrees", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(spin(resolveColor(args[0]), args[1].floatVal)))
  script.addProc(result, "spin", @[paramDef("color", ttyColor), paramDef("degrees", ttyInt)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(spin(resolveColor(args[0]), float(args[1].intVal))))

  # mix
  script.addProc(result, "mix", @[paramDef("a", ttyColor), paramDef("b", ttyColor)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(mix(resolveColor(args[0]), resolveColor(args[1]))))
  # mix with weight
  script.addProc(result, "mix", @[paramDef("a", ttyColor), paramDef("b", ttyColor), paramDef("v", ttyFloat)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(mix(resolveColor(args[0]), resolveColor(args[1]), toWeight(args[2].floatVal))))
  script.addProc(result, "mix", @[paramDef("a", ttyColor), paramDef("b", ttyColor), paramDef("v", ttyInt)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(mix(resolveColor(args[0]), resolveColor(args[1]), toWeight(float(args[2].intVal)))))

  # mixCMYK
  script.addProc(result, "mixCMYK", @[paramDef("a", ttyColor), paramDef("b", ttyColor)], ttyColor,
    proc (args: StackView, argc: int): Value =
      newBroColor(mixCMYK(resolveColor(args[0]), resolveColor(args[1]))))

  # toHex - strict color only
  script.addProc(result, "toHex", @[paramDef("color", ttyColor)], ttyString,
    proc (args: StackView, argc: int): Value =
      initValue(toHex(resolveColor(args[0]))))
  # toHexAlpha
  script.addProc(result, "toHexAlpha", @[paramDef("color", ttyColor)], ttyString,
    proc (args: StackView, argc: int): Value =
      initValue(toHexAlpha(resolveColor(args[0]))))
  # toHtmlHex
  script.addProc(result, "toHtmlHex", @[paramDef("color", ttyColor)], ttyString,
    proc (args: StackView, argc: int): Value =
      initValue(toHtmlHex(resolveColor(args[0]))))

  # parseHex - string -> color is the only legal string entry point
  script.addProc(result, "parseHex", @[paramDef("hex", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let s = args[0].stringVal[]
      newBroColor(parseHex(s), "#" & s))
  script.addProc(result, "parseHexAlpha", @[paramDef("hex", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let s = args[0].stringVal[]
      newBroColor(parseHexAlpha(s), "#" & s))
  script.addProc(result, "parseHtmlHex", @[paramDef("hex", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let s = args[0].stringVal[]
      newBroColor(parseHtmlHex(s), s))
  # generic parseColor bridge for completeness (explicit)
  script.addProc(result, "parseColor", @[paramDef("s", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let s = args[0].stringVal[]
      newBroColor(parseColor(s), s))
  script.addProc(result, "parseHtmlName", @[paramDef("s", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let s = args[0].stringVal[]
      newBroColor(parseHtmlName(s), s))
  script.addProc(result, "parseHtmlColor", @[paramDef("s", ttyString)], ttyColor,
    proc (args: StackView, argc: int): Value =
      let s = args[0].stringVal[]
      newBroColor(parseHtmlColor(s), s))

  # distance - strict color only
  script.addProc(result, "distance", @[paramDef("a", ttyColor), paramDef("b", ttyColor)], ttyFloat,
    proc (args: StackView, argc: int): Value =
      initValue(distance(resolveColor(args[0]), resolveColor(args[1]))))

  # almostEqual - strict
  script.addProc(result, "almostEqual", @[paramDef("a", ttyColor), paramDef("b", ttyColor), paramDef("eps", ttyFloat, isOpt = true)], ttyBool,
    proc (args: StackView, argc: int): Value =
      let eps = if argc >= 3: args[2].floatVal else: 0.01.float32
      initValue(almostEqual(resolveColor(args[0]), resolveColor(args[1]), eps)))

  # echo/toString for Color - prints raw spelling for fidelity
  script.addProc(result, "echo", @[paramDef("x", ttyColor)], ttyVoid,
    proc (args: StackView, argc: int): Value =
      echo broColorToString(args[0]))

  script.addProc(result, "toString", @[paramDef("x", ttyColor)], ttyString,
    proc (args: StackView, argc: int): Value =
      result = initValue(broColorToString(args[0])))
