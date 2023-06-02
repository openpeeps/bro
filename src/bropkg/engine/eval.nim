import std/[macros, math, fenv]
import ./ast

macro isEqualBool*(a, b: bool): untyped =
  result = quote:
    `a` == `b`

macro isNotEqualBool*(a, b: bool): untyped =
  result = quote:
    `a` != `b`

macro isEqualInt*(a, b: int): untyped =
  result = quote:
    `a` == `b`

macro isNotEqualInt*(a, b: int): untyped =
  result = quote:
    `a` != `b`

macro isGreaterInt*(a, b: int): untyped =
  result = quote:
    `a` > `b`

macro isGreaterEqualInt*(a, b: int): untyped =
  result = quote:
    `a` >= `b`

macro isLessInt*(a, b: int): untyped =
  result = quote:
    `a` < `b`

macro isLessEqualInt*(a, b: int): untyped =
  result = quote:
    `a` <= `b`

macro isEqualFloat*(a, b: float64): untyped =
  result = quote:
    `a` == `b`

macro isNotEqualFloat*(a, b: float64): untyped =
  result = quote:
    `a` != `b`

macro isEqualString*(a, b: string): untyped =
  result = quote:
    `a` == `b`

macro isNotEqualString*(a, b: string): untyped =
  result = quote:
    `a` != `b`

# Math
macro mathEpsilon*(x: float): untyped =
  result = quote:
    fenv.epsilon(x)

macro mathTan*(x: float): untyped =
  result = quote:
    math.tan(`x`)

macro mathSin*(x: float): untyped =
  result = quote:
    math.sin(`x`)

macro mathCeil*(x: float): untyped =
  ## Rounds x up to the next highest whole number.
  result = quote:
    math.ceil(`x`)

macro mathClamp*(x: float, min, max: int): untyped =
  ## Restricts x to the given range
  result = quote:
    math.clamp(`x`, `min` .. `max`)

macro mathFloor*(x: float): untyped =
  result = quote:
    math.floor(x)

# min max
# https://github.com/nim-lang/RFCs/issues/439

macro mathRound*(x: float): untyped =
  result = quote:
    math.round(x)

macro mathAbs*(x: float): untyped =
  result = quote:
    abs(x)

macro mathAbs*(x: int): untyped =
  result = quote:
    abs(x)

macro mathHypot*(x, y: float64): untyped =
  ## Computes the length of the hypotenuse of a right-angle
  ## triangle with x as its base and y as its height
  result = quote:
    math.hypot(x, y)

macro mathLog*(x, base: float): untyped =
  ## Computes the logarithm of `x` to `base`
  result = quote:
    math.log(x, base)

proc evalInfix*(infixLeft, infixRight: Node, infixOp: InfixOp, scope: ScopeTable): bool =
  case infixOp:
  of EQ:
    if infixLeft.nt == NTCall:
      if infixRight.nt == NTColor:
        return isEqualString(call(infixLeft).getColor, infixRight.getColor)
      elif infixRight.nt == NTBool:
        return isEqualBool(call(infixLeft).bVal, infixRight.bVal)

  of NE:
    if infixLeft.nt == NTCall:
      if infixRight.nt == NTColor:
        return isNotEqualString(call(infixLeft).getColor, infixRight.getColor)
      elif infixRight.nt == NTBool:
        return isNotEqualBool(call(infixLeft).bVal, infixRight.bVal)
  of AND:
    result =
      evalInfix(infixLeft.infixLeft,infixLeft.infixRight,
                infixLeft.infixOp, scope) and
      evalInfix(infixRight.infixLeft, infixRight.infixRight,
                infixRight.infixOp, scope)
  of OR:
    result =
      evalInfix(infixLeft.infixLeft, infixLeft.infixRight, infixLeft.infixOp, scope) or
      evalInfix(infixRight.infixLeft, infixRight.infixRight, infixRight.infixOp, scope)
  else: discard
