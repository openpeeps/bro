# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

# import std/[macros, math, parseutils, fenv]
import ./ast

# Math
# macro mathEpsilon*(x: float): untyped =
#   result = quote:
#     fenv.epsilon(x)

# macro mathTan*(x: float): untyped =
#   result = quote:
#     math.tan(`x`)

# macro mathSin*(x: float): untyped =
#   result = quote:
#     math.sin(`x`)

# macro mathCeil*(x: float): untyped =
#   ## Rounds x up to the next highest whole number.
#   result = quote:
#     math.ceil(`x`)

# macro mathClamp*(x: float, min, max: int): untyped =
#   ## Restricts x to the given range
#   result = quote:
#     math.clamp(`x`, `min` .. `max`)

# macro mathFloor*(x: float): untyped =
#   result = quote:
#     math.floor(x)

# # min max
# # https://github.com/nim-lang/RFCs/issues/439

# macro mathRound*(x: float): untyped =
#   result = quote:
#     math.round(x)

# macro mathAbs*(x: float): untyped =
#   result = quote:
#     abs(x)

# macro mathAbs*(x: int): untyped =
#   result = quote:
#     abs(x)

# macro mathHypot*(x, y: float64): untyped =
#   ## Computes the length of the hypotenuse of a right-angle
#   ## triangle with x as its base and y as its height
#   result = quote:
#     math.hypot(x, y)

# macro mathLog*(x, base: float): untyped =
#   ## Computes the logarithm of `x` to `base`
#   result = quote:
#     math.log(x, base)

# fwd declaration
proc evalMathInfix*(lht, rht: Node, infixOp: MathOp, scope: ScopeTable): MathResult
proc evalInfix*(lht, rht: Node, infixOp: InfixOp, scope: ScopeTable): bool

proc evalMathInfix*(lht, rht: Node, infixOp: MathOp, scope: ScopeTable): MathResult =
  case infixOp
  of mPlus:
    case lht.nt
    of ntInt:
      case rht.nt:
      of ntInt:
        result = MathResult(mType: mInt, iTotal: lht.iVal + rht.iVal)
      of ntFloat:
        result = MathResult(mType: mFloat, fTotal: toFloat(lht.iVal) + rht.fVal)
      of ntCall:
        var rht = call(rht, scope)
        result = evalMathInfix(lht, rht, infixOp, scope)
      else: discard
    of ntCall:
      var lht = call(lht, scope)
      case rht.nt:
        of ntInt, ntFloat:
          result = evalMathInfix(lht, rht, infixOp, scope)
        of ntCall:
          let rht = call(rht, scope)
          result = evalMathInfix(lht, rht, infixOp, scope)
        else: discard
    else: discard
  of mMinus:
    case lht.nt
    of ntInt:
      case rht.nt:
      of ntInt:
        result = MathResult(mType: mInt, iTotal: lht.iVal - rht.iVal)
      of ntFloat:
        result = MathResult(mType: mFloat, fTotal: toFloat(lht.iVal) - rht.fVal)
      of ntCall:
        var rht = call(rht, scope)
        result = evalMathInfix(lht, rht, infixOp, scope)
      else: discard
    of ntCall:
      var lht = call(lht, scope)
      case rht.nt:
        of ntInt, ntFloat:
          result = evalMathInfix(lht, rht, infixOp, scope)
        of ntCall:
          let rht = call(rht, scope)
          result = evalMathInfix(lht, rht, infixOp, scope)
        else: discard
    else: discard
  of mMulti:
    case lht.nt
    of ntInt:
      case rht.nt:
      of ntInt:
        result = MathResult(mType: mInt, iTotal: lht.iVal * rht.iVal)
      of ntFloat:
        result = MathResult(mType: mFloat, fTotal: toFloat(lht.iVal) * rht.fVal)
      of ntCall:
        var rht = call(rht, scope)
        result = evalMathInfix(lht, rht, infixOp, scope)
      else: discard
    of ntCall:
      var lht = call(lht, scope)
      case rht.nt:
        of ntInt, ntFloat:
          result = evalMathInfix(lht, rht, infixOp, scope)
        of ntCall:
          let rht = call(rht, scope)
          result = evalMathInfix(lht, rht, infixOp, scope)
        else: discard
    else: discard
  of mDiv:
    case lht.nt
    of ntInt:
      case rht.nt:
      of ntInt:
        result = MathResult(mType: mFloat, fTotal: lht.iVal / rht.iVal)
      of ntFloat:
        result = MathResult(mType: mFloat, fTotal: toFloat(lht.iVal) / rht.fVal)
      of ntCall:
        var rht = call(rht, scope)
        result = evalMathInfix(lht, rht, infixOp, scope)
      else: discard
    of ntCall:
      var lht = call(lht, scope)
      case rht.nt:
        of ntInt, ntFloat:
          result = evalMathInfix(lht, rht, infixOp, scope)
        of ntCall:
          let rht = call(rht, scope)
          result = evalMathInfix(lht, rht, infixOp, scope)
        else: discard
    else: discard
  else: discard

proc evalInfix*(lht, rht: Node, infixOp: InfixOp, scope: ScopeTable): bool =
  # todo a macro to generate this ugly statement
  result =
    case infixOp:
    of EQ:
      case lht.nt
      of ntString:
        case rht.nt:
        of ntCall:
          lht.sVal == call(rht, scope).sVal
        of ntString:
          lht.sVal == rht.sVal
        else: false
      of ntCall:
        let l = call(lht, scope)
        case rht.nt
          of ntBool:    l.bVal == rht.bVal
          of ntString:  l.sVal == rht.sVal
          of ntInt:     l.iVal == rht.iVal
          of ntColor:   l.getColor == rht.getColor
          of ntCall:
            evalInfix(l, call(rht, scope), infixOp, scope)
          else: false
      of ntBool:
        case rht.nt:
          of ntBool:    lht.bVal == rht.bVal
          of ntCall:    lht.bVal == call(rht, scope).bVal
          else: false
      of ntInt:
        case rht.nt:
          of ntInt:     lht.iVal == rht.iVal
          of ntCall:    lht.iVal == call(rht, scope).iVal
          of ntFloat:   toFloat(lht.iVal) == rht.fVal
          else: false
      of ntFloat:
        case rht.nt:
          of ntFloat:   lht.fVal == rht.fVal
          of ntInt:     lht.fVal == toFloat(rht.iVal)
          of ntCall:    lht.fVal == toFloat(call(rht, scope).iVal)
          else: false
      else: false
    of NE:
      case lht.nt
      of ntString:
        case rht.nt:
        of ntCall:
          lht.sVal != call(rht, scope).sVal
        of ntString:
          lht.sVal != rht.sVal
        else: false
      of ntCall:
        let l = call(lht, scope)
        case rht.nt
          of ntBool:    l.bVal != rht.bVal
          of ntString:  l.sVal != rht.sVal
          of ntInt:     l.iVal != rht.iVal
          of ntColor:   l.getColor != rht.getColor
          of ntCall:
            evalInfix(l, call(rht, scope), infixOp, scope)
          else: false
      of ntBool:
        case rht.nt:
          of ntBool:    lht.bVal != rht.bVal
          of ntCall:    lht.bVal != call(rht, scope).bVal
          else: false
      of ntInt:
        case rht.nt:
          of ntInt:     lht.iVal != rht.iVal
          of ntCall:    lht.iVal != call(rht, scope).iVal
          of ntFloat:   toFloat(lht.iVal) != rht.fVal
          else: false
      of ntFloat:
        case rht.nt:
          of ntFloat:   lht.fVal != rht.fVal
          of ntInt:     lht.fVal != toFloat(rht.iVal)
          of ntCall:    lht.fVal != toFloat(call(rht, scope).iVal)
          else: false
      else: false
    of LT:
      case lht.nt:
      of ntInt:
        case rht.nt:
          of ntInt:     lht.iVal < rht.iVal
          of ntCall:    lht.iVal < call(rht, scope).iVal
          else: false
      of ntFloat:
        case rht.nt:
          of ntFloat:   lht.fVal < rht.fVal
          of ntInt:     lht.fVal < toFloat(rht.iVal)
          of ntCall:    lht.fVal < toFloat(call(rht, scope).iVal)
          else: false
      of ntCall:
        case rht.nt:
          of ntInt:    call(lht, scope).iVal < rht.iVal
          of ntCall:   call(lht, scope).iVal < call(rht, scope).iVal
          else: false
      else: false
    of LTE:
      case lht.nt:
      of ntInt:
        case rht.nt:
          of ntInt:     lht.iVal <= rht.iVal
          of ntCall:    lht.iVal <= call(rht, scope).iVal
          else: false
      of ntCall:
        case rht.nt:
          of ntInt:    call(lht, scope).iVal <= rht.iVal
          of ntCall:   call(lht, scope).iVal <= call(rht, scope).iVal
          else: false
      else: false
    of GT:
      case lht.nt:
      of ntInt:
        case rht.nt:
          of ntInt:     lht.iVal > rht.iVal
          of ntCall:    lht.iVal > call(rht, scope).iVal
          else: false
      of ntCall:
        case rht.nt:
          of ntInt:    call(lht, scope).iVal > rht.iVal
          of ntCall:   call(lht, scope).iVal > call(rht, scope).iVal
          else: false
      else: false
    of GTE:
      case lht.nt:
      of ntInt:
        case rht.nt:
          of ntInt:     lht.iVal >= rht.iVal
          of ntCall:    lht.iVal >= call(rht, scope).iVal
          else: false
      of ntCall:
        case rht.nt:
          of ntInt:    call(lht, scope).iVal >= rht.iVal
          of ntCall:   call(lht, scope).iVal >= call(rht, scope).iVal
          else: false
      else: false
    of AND:
      evalInfix(lht.infixLeft, lht.infixRight, lht.infixOp, scope) and
        evalInfix(rht.infixLeft, rht.infixRight, rht.infixOp, scope)
    of OR:
      evalInfix(lht.infixLeft, lht.infixRight, lht.infixOp, scope) or
        evalInfix(rht.infixLeft, rht.infixRight, rht.infixOp, scope)
    else: false
