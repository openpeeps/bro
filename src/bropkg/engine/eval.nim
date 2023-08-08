# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro


# fwd declaration
proc evalMathInfix*(c: Compiler, lht, rht: Node, infixOp: MathOp, scope: ScopeTable): Node
proc evalInfix*(c: Compiler, lht, rht: Node, infixOp: InfixOp, scope: ScopeTable): bool

proc plus(lht, rht: int): int {.inline.} = lht + rht
proc plus(lht, rht: float): float {.inline.} = lht + rht

proc minus(lht, rht: int): int {.inline.} = lht - rht
proc minus(lht, rht: float): float {.inline.} = lht - rht

proc multi(lht, rht: int): int {.inline.} = lht * rht
proc multi(lht, rht: float): float {.inline.} = lht * rht

proc divide(lht, rht: int): float {.inline.} = lht / rht
proc divide(lht, rht: float): float {.inline.} = lht / rht
proc modulo(lht, rht: int): int {.inline.} = lht mod rht

template calc(calcHandle): untyped {.dirty.} =
  case lht.nt
  of ntInt:
    case rht.nt:
    of ntInt:
      let x = calcHandle(lht.iVal.toFloat, rht.iVal.toFloat)
      if x mod 1 != 0:
        Node(nt: ntFloat, fVal: x)
      else:
        Node(nt: ntInt, iVal: int(x))
    of ntFloat:
      Node(nt: ntFloat, fVal: calcHandle(toFloat(lht.iVal), rht.fVal))
    of ntCall:
      var rht = call(rht, scope)
      c.evalMathInfix(lht, rht, infixOp, scope)
    of ntMathStmt:
      var rht = c.evalMathInfix(rht.mathLeft, rht.mathRight, rht.mathInfixOp, scope)
      c.evalMathInfix(lht, rht, infixOp, scope)
    else: nil
  of ntFloat:
    case rht.nt:
    of ntInt:
      let x = calcHandle(lht.fVal, rht.iVal.toFloat)
      if x mod 1 != 0:
        Node(nt: ntFloat, fVal: x)
      else:
        Node(nt: ntInt, iVal: int(x))
    of ntFloat:
      Node(nt: ntFloat, fVal: calcHandle(lht.fVal, rht.fVal))
    of ntCall:
      var rht = call(rht, scope)
      c.evalMathInfix(lht, rht, infixOp, scope)
    of ntMathStmt:
      var rht = c.evalMathInfix(rht.mathLeft, rht.mathRight, rht.mathInfixOp, scope)
      c.evalMathInfix(lht, rht, infixOp, scope)
    else: nil
  of ntSize:
    case lht.sizeVal.nt
    of ntInt:
      case rht.nt
        of ntSize:
          if rht.sizeVal.nt == ntInt:
            newSize(calcHandle(lht.sizeVal.iVal, rht.sizeVal.iVal), lht.sizeUnit)
          elif rht.sizeVal.nt == ntFloat:
            newSize(calcHandle(toFloat(lht.sizeVal.iVal), rht.sizeVal.fVal), lht.sizeUnit)
          else: nil
        else: nil # todo handle int/float callables
    of ntFloat:
      case rht.nt
        of ntSize:
          if rht.sizeVal.nt == ntInt:
            newSize(calcHandle(lht.sizeVal.fVal, toFloat(rht.sizeVal.iVal)), lht.sizeUnit)
          elif rht.sizeVal.nt == ntFloat:
            newSize(calcHandle(lht.sizeVal.fVal, rht.sizeVal.fVal), lht.sizeUnit)
          else: nil
        else: nil # todo handle int/float callables
    else: nil
  of ntCall:
    var lht = call(lht, scope)
    if lht.nt == ntMathStmt:
      lht = c.evalMathInfix(lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
    case rht.nt:
      of ntInt, ntFloat:
        c.evalMathInfix(lht, rht, infixOp, scope)
      of ntCall:
        let rht = call(rht, scope)
        c.evalMathInfix(lht, rht, infixOp, scope)
      else: nil
  of ntMathStmt:
    var lht = c.evalMathInfix(lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
    c.evalMathInfix(lht, rht, infixOp, scope)
  else:
    nil # todo handle function calls

proc evalMathInfix*(c: Compiler, lht, rht: Node, infixOp: MathOp, scope: ScopeTable): Node =
  case infixOp
  of mPlus:   calc(plus)
  of mMinus:  calc(minus)
  of mMulti:  calc(multi)
  of mDiv:    calc(divide)
  # of mMod:    calcFloat(modulo)
  else: nil

template ofMath: untyped {.dirty.} =
  var rht = evalMathInfix(c, rht.mathLeft, rht.mathRight, rht.mathInfixOp, scope)
  evalInfix(c, lht, rht, infixOp, scope)

template ofMathLeft: untyped {.dirty.} =
  var lht = evalMathInfix(c, lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
  evalInfix(c, lht, rht, infixOp, scope)

template ofCallStack: untyped {.dirty.} =
  var rht = handleCallStack(c, rht, scope)
  evalInfix(c, lht, rht, infixOp, scope)

template ofSize: untyped {.dirty.} =
  evalinfix(c, lht.sizeVal, rht.sizeVal, infixOp, scope)

proc evalInfix(c: Compiler; lht, rht: Node; infixOp: InfixOp; scope: ScopeTable): bool =
  return case infixOp
  of EQ:
    # compares `lht` node if EQUALS with `rht`
    # comparable nodes:
    #   ntInt, ntFloat, ntString, ntBool,
    #   ntCall, ntCallStack, ntInfix, ntMathInfix
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:
        lht.iVal == rht.iVal
      of ntFloat:
        toFloat(lht.iVal) == rht.fVal
      of ntCall:
        lht.iVal == call(rht, scope).iVal
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      else:
        false
    of ntFloat:
      case rht.nt
      of ntFloat:
        lht.fVal == rht.fVal
      of ntInt:
        lht.fVal == toFloat(rht.iVal)
      of ntCall:
        lht.fVal == call(rht, scope).fVal
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      else:
        false
    of ntString:
      case rht.nt
      of ntString:
        lht.sVal == rht.sVal
      of ntCall:
        lht.sVal == call(rht, scope).sVal
      of ntCallStack: ofCallStack
      else:
        false
    of ntBool:
      case rht.nt
      of ntBool:
        lht.bVal == rht.bVal
      of ntCall:
        lht.bVal == call(rht, scope).bVal
      of ntCallStack: ofCallStack
      else:
        false
    of ntColor:
      case rht.nt
      of ntColor:
        lht.getColor == rht.getColor
      else:
        false
    of ntCall:
      var lht = call(lht, scope)
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      of ntSize: ofSize
      else:
        false
    of ntCallStack:
      var lht = handleCallStack(c, lht, scope)
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      of ntSize: ofSize
      else:
        false
    of ntMathStmt: ofMathLeft
    of ntSize: ofSize
    else:
      false
  of NE:
    # compares `lht` NOT EQUAL with `rht` node
    # comparable nodes:
    #   ntInt, ntFloat, ntString, ntBool,
    #   ntCall, ntCallStack, ntInfix, ntMathInfix
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:
        lht.iVal != rht.iVal
      of ntFloat:
        toFloat(lht.iVal) != rht.fVal
      of ntCall:
        lht.iVal != call(rht, scope).iVal
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      else:
        false
    of ntFloat:
      case rht.nt
      of ntFloat:
        lht.fVal != rht.fVal
      of ntInt:
        lht.fVal != toFloat(rht.iVal)
      of ntCall:
        lht.fVal != call(rht, scope).fVal
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      else:
        false
    of ntString:
      case rht.nt
      of ntString:
        lht.sVal != rht.sVal
      of ntCall:
        lht.sVal != call(rht, scope).sVal
      of ntCallStack: ofCallStack
      else:
        false
    of ntBool:
      case rht.nt
      of ntBool:
        lht.bVal != rht.bVal
      of ntCall:
        lht.bVal != call(rht, scope).bVal
      of ntCallStack: ofCallStack
      else:
        false
    of ntColor:
      case rht.nt
      of ntColor:
        lht.getColor != rht.getColor
      else:
        false
    of ntCall:
      var lht = call(lht, scope)
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      of ntSize: ofSize
      else:
        false
    of ntCallStack:
      var lht = handleCallStack(c, lht, scope)
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      of ntSize: ofSize
      else:
        false
    of ntMathStmt: ofMathLeft
    of ntSize: ofSize
    else:
      false
  of LT:
    # compares `lht` node if is LESS THAN `rht` node
    # comparable nodes:
    #   ntInt, ntFloat ntCall, ntCallStack, ntInfix, ntMathInfix
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:
        lht.iVal < rht.iVal
      of ntFloat:
        toFloat(lht.iVal) < rht.fVal
      of ntCall:
        lht.iVal < call(rht, scope).iVal
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      else:
        false
    of ntFloat:
      case rht.nt
      of ntFloat:
        lht.fVal < rht.fVal
      of ntInt:
        lht.fVal < toFloat(rht.iVal)
      of ntCall:
        lht.fVal < call(rht, scope).fVal
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      else:
        false
    of ntCall:
      var lht = call(lht, scope)
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      of ntSize: ofSize
      else:
        false
    of ntCallStack:
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      of ntSize: ofSize
      else:
        false
    of ntMathStmt: ofMathLeft
    of ntSize: ofSize
    else:
      false
  of LTE:
    # compares `lht` node if LESS THAN OR EQUAL with `rht` node
    # comparable nodes:
    #   ntInt, ntFloat ntCall, ntCallStack, ntInfix, ntMathInfix
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:
        lht.iVal <= rht.iVal
      of ntFloat:
        toFloat(lht.iVal) <= rht.fVal
      of ntCall:
        lht.iVal <= call(rht, scope).iVal
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      else:
        false
    of ntFloat:
      case rht.nt
      of ntFloat:
        lht.fVal <= rht.fVal
      of ntInt:
        lht.fVal <= toFloat(rht.iVal)
      of ntCall:
        lht.fVal <= call(rht, scope).fVal
      of ntCallStack: ofCallStack
      else:
        false
    of ntCall:
      var lht = call(lht, scope)
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      of ntSize: ofSize
      else:
        false
    of ntCallStack:
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      of ntSize: ofSize
      else:
        false
    of ntMathStmt: ofMathLeft
    of ntSize: ofSize
    else:
      false
  of GT:
    # compares `lht` node if GREATER than `rht`
    # comparable nodes:
    #   ntInt, ntFloat ntCall, ntCallStack, ntInfix, ntMathInfix
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:
        lht.iVal > rht.iVal
      of ntFloat:
        toFloat(lht.iVal) > rht.fVal
      of ntCall:
        lht.iVal > call(rht, scope).iVal
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      else:
        false
    of ntFloat:
      case rht.nt
      of ntFloat:
        lht.fVal > rht.fVal
      of ntInt:
        lht.fVal > toFloat(rht.iVal)
      of ntCall:
        lht.fVal > call(rht, scope).fVal
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      else:
        false
    of ntCall:
      var lht = call(lht, scope)
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack:
        var rht = handleCallStack(c, rht, scope)
        evalInfix(c, lht, rht, infixOp, scope)
      of ntSize: ofSize 
      else:
        false
    of ntCallStack:
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      of ntSize: ofSize
      else:
        false
    of ntMathStmt: ofMathLeft
    of ntSize: ofSize
    else:
      false
  of GTE:
    # compares `lht` node if GREATER or EQUAL than `rht`
    # comparable nodes:
    #   ntInt, ntFloat ntCall, ntCallStack, ntInfix, ntMathInfix
    case lht.nt
    of ntInt:
      case rht.nt
      of ntInt:
        lht.iVal >= rht.iVal
      of ntFloat:
        toFloat(lht.iVal) >= rht.fVal
      of ntCall:
        lht.iVal >= call(rht, scope).iVal
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      else:
        false
    of ntFloat:
      case rht.nt
      of ntFloat:
        lht.fVal >= rht.fVal
      of ntInt:
        lht.fVal >= toFloat(rht.iVal)
      of ntCall:
        lht.fVal >= call(rht, scope).fVal
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      else:
        false
    of ntCall:
      var lht = call(lht, scope)
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      of ntSize: ofSize
      else:
        false
    of ntCallStack:
      case rht.nt
      of ntBool, ntFloat, ntInt, ntString, ntColor:
        evalInfix(c, lht, rht, infixOp, scope)
      of ntCall:
        evalInfix(c, lht, call(rht, scope), infixOp, scope)
      of ntCallStack: ofCallStack
      of ntMathStmt: ofMath
      of ntSize: ofSize
      else:
        false
    of ntMathStmt: ofMathLeft
    of ntSize: ofSize
    else:
      false
  of AND:
    false
  of OR:
    false
  else:
    false