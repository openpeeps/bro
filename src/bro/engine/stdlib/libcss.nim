# CSS strict typed values for Bro — length, angle, time, resolution, flex
#
# Every CSS unit is a typed foreign Object (Value with isForeign objectVal)
# wrapping a plain-object payload from cssvalues (never ref). No
# tyString/tyInt fallback anywhere: strict type errors on mismatch.
# (c) 2026 George Lemon | LGPL-v3 License

import std/[strutils, options, tables]
import pkg/vancode/interpreter/[ast, chunk, sym, value]
import ./inliner
import ./cssvalues
import ../vancodegen  # brings ttyLength etc into scope
import ../parser as broParser

proc parseCssUnit(s: string): tuple[val: float, unit: string, ok: bool] =
  if s.len == 0: return (0, "", false)
  var i = 0
  if s[0] in {'-', '+'}: inc i
  while i < s.len and s[i] in {'0'..'9', '.'}:
    inc i
  if i < s.len and s[i] in {'e', 'E'}:
    inc i
    if i < s.len and s[i] in {'-', '+'}: inc i
    while i < s.len and s[i] in {'0'..'9'}:
      inc i
  if i == 0 or (i == 1 and s[0] in {'-', '+'}):
    return (0, "", false)
  try:
    let num = parseFloat(s[0..<i])
    let unit = s[i..^1]
    if unit.len == 0:
      return (num, "", true)
    if unit in broParser.unitSizeSuffixes or unit == "%":
      return (num, unit, true)
    else:
      return (0, "", false)
  except:
    return (0, "", false)

proc newCssSize*(s: string): Value =
  let p = parseCssUnit(s)
  if not p.ok:
    raise newException(ValueError, "Invalid length value: '" & s & "'")
  initCssPayload(ord(ttyLength), CssSize(val: p.val, unit: p.unit), cssNumStr(p.val) & p.unit)

proc newCssSizeRaw*(val: float, unit: string): Value =
  initCssPayload(ord(ttyLength), CssSize(val: val, unit: unit), cssNumStr(val) & unit)

proc newCssAngle*(s: string): Value =
  let p = parseCssUnit(s)
  if not p.ok or p.unit notin ["deg", "rad", "grad", "turn"]:
    raise newException(ValueError, "Invalid angle value: '" & s & "'")
  initCssPayload(ord(ttyAngle), CssAngle(val: p.val, unit: p.unit), cssNumStr(p.val) & p.unit)

proc newCssAngleRaw*(val: float, unit: string): Value =
  initCssPayload(ord(ttyAngle), CssAngle(val: val, unit: unit), cssNumStr(val) & unit)

proc newCssTime*(s: string): Value =
  let p = parseCssUnit(s)
  if not p.ok or p.unit notin ["s", "ms"]:
    raise newException(ValueError, "Invalid time value: '" & s & "'")
  initCssPayload(ord(ttyTime), CssTime(val: p.val, unit: p.unit), cssNumStr(p.val) & p.unit)

proc newCssTimeRaw*(val: float, unit: string): Value =
  initCssPayload(ord(ttyTime), CssTime(val: val, unit: unit), cssNumStr(val) & unit)

proc newCssResolution*(s: string): Value =
  let p = parseCssUnit(s)
  if not p.ok or p.unit notin ["dpi", "dpcm", "dppx"]:
    raise newException(ValueError, "Invalid resolution value: '" & s & "'")
  initCssPayload(ord(ttyResolution), CssResolution(val: p.val, unit: p.unit), cssNumStr(p.val) & p.unit)

proc newCssFlex*(s: string): Value =
  let p = parseCssUnit(s)
  if not p.ok or p.unit != "fr":
    raise newException(ValueError, "Invalid flex value: '" & s & "'")
  initCssPayload(ord(ttyFlex), CssFlex(val: p.val, unit: p.unit), cssNumStr(p.val) & p.unit)

proc cssSizeToString*(v: Value): string =
  if v.typeId != ord(ttyLength):
    raise newException(ValueError, "type mismatch: expected length, got typeId " & $v.typeId)
  let c = v.foreign(CssSize)
  cssNumStr(c.val) & c.unit

proc cssAngleToString*(v: Value): string =
  if v.typeId != ord(ttyAngle):
    raise newException(ValueError, "type mismatch: expected angle, got typeId " & $v.typeId)
  let c = v.foreign(CssAngle)
  cssNumStr(c.val) & c.unit

proc cssTimeToString*(v: Value): string =
  if v.typeId != ord(ttyTime):
    raise newException(ValueError, "type mismatch: expected time, got typeId " & $v.typeId)
  let c = v.foreign(CssTime)
  cssNumStr(c.val) & c.unit

proc cssResolutionToString*(v: Value): string =
  if v.typeId != ord(ttyResolution):
    raise newException(ValueError, "type mismatch: expected resolution, got typeId " & $v.typeId)
  let c = v.foreign(CssResolution)
  cssNumStr(c.val) & c.unit

proc cssFlexToString*(v: Value): string =
  if v.typeId != ord(ttyFlex):
    raise newException(ValueError, "type mismatch: expected flex, got typeId " & $v.typeId)
  let c = v.foreign(CssFlex)
  cssNumStr(c.val) & c.unit

proc toCssSize(v: Value): CssSize =
  if v.typeId != ord(ttyLength):
    raise newException(ValueError, "type mismatch: expected length, got typeId " & $v.typeId)
  v.foreign(CssSize)

proc toCssAngle(v: Value): CssAngle =
  if v.typeId != ord(ttyAngle):
    raise newException(ValueError, "type mismatch: expected angle, got typeId " & $v.typeId)
  v.foreign(CssAngle)

proc toCssTime(v: Value): CssTime =
  if v.typeId != ord(ttyTime):
    raise newException(ValueError, "type mismatch: expected time, got typeId " & $v.typeId)
  v.foreign(CssTime)

proc initCssTypes*(script: Script, systemModule: Module): Module =
  result = newModule("cssTypes", some"std::cssTypes")
  result.load(systemModule)

  let symLength = genType(ttyLength, "length", true)
  result.add(symLength)
  discard result.addType(symLength, newIdent("ttyLength"))
  let symAngle = genType(ttyAngle, "angle", true)
  result.add(symAngle)
  discard result.addType(symAngle, newIdent("ttyAngle"))
  let symTime = genType(ttyTime, "time", true)
  result.add(symTime)
  discard result.addType(symTime, newIdent("ttyTime"))
  let symRes = genType(ttyResolution, "resolution", true)
  result.add(symRes)
  discard result.addType(symRes, newIdent("ttyResolution"))
  let symFlex = genType(ttyFlex, "flex", true)
  result.add(symFlex)
  discard result.addType(symFlex, newIdent("ttyFlex"))
  if not result.typeDefs.hasKey("number"):
    let symNum = genType(ttyNumber, "number", true)
    result.add(symNum)
    discard result.addType(symNum, newIdent("ttyNumber"))

  let tLen = result.typeDefs["length"]
  script.addProc(result, "+", @[paramDef("a", ttyLength, sym = tLen), paramDef("b", ttyLength, sym = tLen)], ttyLength,
    proc (args: StackView, argc: int): Value =
      let a = toCssSize(args[0])
      let b = toCssSize(args[1])
      if a.unit != b.unit:
        raise newException(ValueError, "Mismatched units for '+': '" & a.unit & "' vs '" & b.unit & "'")
      result = initCssPayload(ord(ttyLength), CssSize(val: a.val + b.val, unit: a.unit), cssNumStr(a.val + b.val) & a.unit)
  )
  script.addProc(result, "-", @[paramDef("a", ttyLength, sym = tLen), paramDef("b", ttyLength, sym = tLen)], ttyLength,
    proc (args: StackView, argc: int): Value =
      let a = toCssSize(args[0])
      let b = toCssSize(args[1])
      if a.unit != b.unit:
        raise newException(ValueError, "Mismatched units for '-': '" & a.unit & "' vs '" & b.unit & "'")
      result = initCssPayload(ord(ttyLength), CssSize(val: a.val - b.val, unit: a.unit), cssNumStr(a.val - b.val) & a.unit)
  )
  script.addProc(result, "echo", @[paramDef("x", ttyLength, sym = tLen)], ttyVoid,
    proc (args: StackView, argc: int): Value =
      echo cssSizeToString(args[0])
  )
  script.addProc(result, "toString", @[paramDef("x", ttyLength, sym = tLen)], ttyString,
    proc (args: StackView, argc: int): Value =
      result = initValue(cssSizeToString(args[0]))
  )

  let tAngle = result.typeDefs["angle"]
  script.addProc(result, "+", @[paramDef("a", ttyAngle, sym = tAngle), paramDef("b", ttyAngle, sym = tAngle)], ttyAngle,
    proc (args: StackView, argc: int): Value =
      let a = toCssAngle(args[0])
      let b = toCssAngle(args[1])
      if a.unit != b.unit:
        raise newException(ValueError, "Mismatched units for '+': '" & a.unit & "' vs '" & b.unit & "'")
      result = initCssPayload(ord(ttyAngle), CssAngle(val: a.val + b.val, unit: a.unit), cssNumStr(a.val + b.val) & a.unit)
  )
  script.addProc(result, "-", @[paramDef("a", ttyAngle, sym = tAngle), paramDef("b", ttyAngle, sym = tAngle)], ttyAngle,
    proc (args: StackView, argc: int): Value =
      let a = toCssAngle(args[0])
      let b = toCssAngle(args[1])
      if a.unit != b.unit:
        raise newException(ValueError, "Mismatched units for '-': '" & a.unit & "' vs '" & b.unit & "'")
      result = initCssPayload(ord(ttyAngle), CssAngle(val: a.val - b.val, unit: a.unit), cssNumStr(a.val - b.val) & a.unit)
  )
  script.addProc(result, "echo", @[paramDef("x", ttyAngle, sym = tAngle)], ttyVoid,
    proc (args: StackView, argc: int): Value = echo cssAngleToString(args[0]))
  script.addProc(result, "toString", @[paramDef("x", ttyAngle, sym = tAngle)], ttyString,
    proc (args: StackView, argc: int): Value = result = initValue(cssAngleToString(args[0])))

  let tTime = result.typeDefs["time"]
  script.addProc(result, "+", @[paramDef("a", ttyTime, sym = tTime), paramDef("b", ttyTime, sym = tTime)], ttyTime,
    proc (args: StackView, argc: int): Value =
      let a = toCssTime(args[0])
      let b = toCssTime(args[1])
      if a.unit != b.unit:
        raise newException(ValueError, "Mismatched units for '+': '" & a.unit & "' vs '" & b.unit & "'")
      result = initCssPayload(ord(ttyTime), CssTime(val: a.val + b.val, unit: a.unit), cssNumStr(a.val + b.val) & a.unit)
  )
  script.addProc(result, "-", @[paramDef("a", ttyTime, sym = tTime), paramDef("b", ttyTime, sym = tTime)], ttyTime,
    proc (args: StackView, argc: int): Value =
      let a = toCssTime(args[0])
      let b = toCssTime(args[1])
      if a.unit != b.unit:
        raise newException(ValueError, "Mismatched units for '-': '" & a.unit & "' vs '" & b.unit & "'")
      result = initCssPayload(ord(ttyTime), CssTime(val: a.val - b.val, unit: a.unit), cssNumStr(a.val - b.val) & a.unit)
  )
  script.addProc(result, "echo", @[paramDef("x", ttyTime, sym = tTime)], ttyVoid,
    proc (args: StackView, argc: int): Value = echo cssTimeToString(args[0]))
  script.addProc(result, "toString", @[paramDef("x", ttyTime, sym = tTime)], ttyString,
    proc (args: StackView, argc: int): Value = result = initValue(cssTimeToString(args[0])))

  # Explicit string -> typed constructors (also used by codegen for unit
  # literals, so `4px` is a length value at runtime instead of a string).
  script.addProc(result, "parseLength", @[paramDef("s", ttyString)], ttyLength,
    proc (args: StackView, argc: int): Value =
      result = newCssSize(args[0].stringVal[]))
  script.addProc(result, "parseAngle", @[paramDef("s", ttyString)], ttyAngle,
    proc (args: StackView, argc: int): Value =
      result = newCssAngle(args[0].stringVal[]))
  script.addProc(result, "parseTime", @[paramDef("s", ttyString)], ttyTime,
    proc (args: StackView, argc: int): Value =
      result = newCssTime(args[0].stringVal[]))
  script.addProc(result, "parseResolution", @[paramDef("s", ttyString)], ttyResolution,
    proc (args: StackView, argc: int): Value =
      result = newCssResolution(args[0].stringVal[]))
  script.addProc(result, "parseFlex", @[paramDef("s", ttyString)], ttyFlex,
    proc (args: StackView, argc: int): Value =
      result = newCssFlex(args[0].stringVal[]))

  let tRes = result.typeDefs["resolution"]
  script.addProc(result, "echo", @[paramDef("x", ttyResolution, sym = tRes)], ttyVoid,
    proc (args: StackView, argc: int): Value = echo cssResolutionToString(args[0]))
  script.addProc(result, "toString", @[paramDef("x", ttyResolution, sym = tRes)], ttyString,
    proc (args: StackView, argc: int): Value = result = initValue(cssResolutionToString(args[0])))

  let tFlex = result.typeDefs["flex"]
  script.addProc(result, "echo", @[paramDef("x", ttyFlex, sym = tFlex)], ttyVoid,
    proc (args: StackView, argc: int): Value = echo cssFlexToString(args[0]))
  script.addProc(result, "toString", @[paramDef("x", ttyFlex, sym = tFlex)], ttyString,
    proc (args: StackView, argc: int): Value = result = initValue(cssFlexToString(args[0])))
