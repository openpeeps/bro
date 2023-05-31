# import std/math
# # abs, floor

# # TODO implement all math functions and more
# # https://sass-lang.com/documentation/modules/math

# # use
# # https://nim-lang.org/docs/math.html
# # https://nim-lang.org/docs/system.html#abs%2Cint

import macros
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
