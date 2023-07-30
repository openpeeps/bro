# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro


# fwd declaration
proc evalMathInfix*(c: var Compiler, lht, rht: Node, infixOp: MathOp, scope: ScopeTable): Node
proc evalInfix*(c: var Compiler, lht, rht: Node, infixOp: InfixOp, scope: ScopeTable): bool

proc plus(lht, rht: int): int {.inline.} = lht + rht
proc plus(lht, rht: float): float {.inline.} = lht + rht

proc minus(lht, rht: int): int {.inline.} = lht - rht
proc minus(lht, rht: float): float {.inline.} = lht - rht

proc multi(lht, rht: int): int {.inline.} = lht * rht
proc multi(lht, rht: float): float {.inline.} = lht * rht

proc divide(lht, rht: int): int {.inline.} = lht div rht
proc modulo(lht, rht: int): int {.inline.} = lht mod rht

template calc(calcHandle): untyped {.dirty.} =
  case lht.nt
  of ntInt:
    case rht.nt:
    of ntInt:
      Node(nt: ntInt, iVal: calcHandle(lht.iVal, rht.iVal))
    of ntFloat:
      Node(nt: ntFloat, fVal: calcHandle(toFloat(lht.iVal), rht.fVal))
    of ntCall:
      var rht = call(rht, scope)
      c.evalMathInfix(lht, rht, infixOp, scope)
    of ntMathStmt:
      var rht = c.evalMathInfix(rht.mathLeft, rht.mathRight, rht.mathInfixOp, scope)
      c.evalMathInfix(lht, rht, infixOp, scope)
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
  else: nil

template calcInt(calcHandle): untyped {.dirty.} =
  case lht.nt
  of ntInt:
    case rht.nt:
    of ntInt:
      Node(nt: ntInt, iVal: calcHandle(lht.iVal, rht.iVal))
    of ntCall:
      var rht = call(rht, scope)
      c.evalMathInfix(lht, rht, infixOp, scope)
    else: nil
  of ntCall:
    var lht = call(lht, scope)
    if lht.nt == ntMathStmt:
      lht = c.evalMathInfix(lht.mathLeft, lht.mathRight, lht.mathInfixOp, scope)
    case rht.nt:
      of ntInt:
        c.evalMathInfix(lht, rht, infixOp, scope)
      of ntCall:
        let rht = call(rht, scope)
        c.evalMathInfix(lht, rht, infixOp, scope)
      else: nil
  else: nil

proc evalMathInfix*(c: var Compiler, lht, rht: Node, infixOp: MathOp, scope: ScopeTable): Node =
  case infixOp
  of mPlus:   calc(plus)
  of mMinus:  calc(minus)
  of mMulti:  calcInt(multi)
  of mDiv:    calcInt(divide)
  of mMod:    calcInt(modulo)
  else: nil

macro genInfixEval() =
  proc genInfixOp(op, fname: string): NimNode =
    result = newNimNode(nnkInfix)
    result.add(
      ident(op),
      newDotExpr(ident("lht"), ident(fname)),
      newDotExpr(ident("rht"), ident(fname)))

  proc genInfixOp(op, lht: string, rht: NimNode): NimNode =
    result = newNimNode(nnkInfix)
    add result, ident(op), newDotExpr(ident("lht"), ident(lht)), rht

  proc genInfixOp(op: string, lht, rht: NimNode): NimNode =
    result = newNimNode(nnkInfix)
    result.add(ident(op), lht, rht)

  proc rhtBranch(nt, op, fName: string): NimNode =
    result = newNimNode(nnkOfBranch)
    result.add(ident(nt), genInfixOp(op, fName))

  proc rhtBranch(nt, op, lht: string, rht: NimNode): NimNode =
    result = newNimNode(nnkOfBranch)
    result.add(ident(nt), genInfixOp(op, lht, rht))

  proc rhtBranch(nt, op: string, lht, rht: NimNode): NimNode =
    result = newNimNode(nnkOfBranch)
    result.add(ident(nt), genInfixOp(op, lht, rht))

  proc rhtBranchRec(nt, op: string): NimNode =
    result = newNimNode(nnkOfBranch)
    result.add(ident(nt), nnkStmtList.newTree(
      newVarStmt(
        ident("rht"),
        newcall(ident("handleCallStack"), ident("c"), ident("rht"), ident("scope"))
      ),
      newCall(ident("evalInfix"),  ident("c"), ident("lht"),
              ident("rht"), ident("infixOp"), ident("scope"))))

  proc rhtBranchToFloat(nt, op, fname: string): NimNode =
    result =
      rhtBranch("ntFloat", op,
        newCall(ident("toFloat"), newDotExpr(ident("lht"), ident(fname))),
        newDotExpr(ident("rht"), ident("fVal")))

  proc toFloatNode(node, fname: string): NimNode =
    newCall(ident("toFloat"),
      newDotExpr(ident(node), ident(fname)))

  proc rhtCall(fname: string): NimNode =
    result =
      newDotExpr(
        newCall(ident("call"), ident("rht"), ident("scope")),
        ident(fname))

  proc getDefaultCallableCase(): NimNode =
    result = newNimNode(nnkOfBranch)
    add result,
      ident("ntBool"), ident("ntFloat"),
      ident("ntInt"), ident("ntString"),
      ident("ntColor"),
      newStmtList(
        newCall(
          ident("evalInfix"),
          ident("c"),
          ident("lht"),
          ident("rht"),
          ident("infixOp"), ident("scope")
        )
      )

  proc getCallRec(): NimNode =
    result = newNimNode(nnkOfBranch)
    add result,
      ident("ntCall"),
      newCall(
        ident("evalInfix"),
        ident("c"),
        ident("lht"),
        newCall(
          ident("call"),
          ident("rht"),
          ident("scope")
        ),
        ident("infixOp"), ident("scope")
      )

  proc rhtCaseHandler(lident: NimNode, op: string): NimNode =
    result = newNimNode(nnkCaseStmt)
    add result, newDotExpr(ident("rht"), ident("nt"))
    if eqIdent(lident, "ntString"):
      var fname = "sVal"
      add result, rhtBranch("ntString", op, fname)
      add result, rhtBranch("ntCall", op, fname, rhtCall(fname))
      add result, rhtBranchRec("ntCallStack", op)
    elif eqIdent(lident, "ntBool"):
      var fname = "bVal"
      add result, rhtBranch("ntBool", op, fname)
      add result, rhtBranch("ntCall", op, fname, rhtCall(fname))
      add result, rhtBranchRec("ntCallStack", op)
    elif eqIdent(lident, "ntInt"):
      var fname = "iVal"
      add result, rhtBranch("ntInt", op, fname)
      # add result, rhtBranchToFloat("ntFloat", op, fname)
      add result, rhtBranch("ntFloat", op, toFloatNode("lht", "iVal"), newDotExpr(ident("rht"), ident("fVal")))
      add result, rhtBranch("ntCall", op, fname, rhtCall(fname))
      add result, rhtBranchRec("ntCallStack", op)
    elif eqIdent(lident, "ntFloat"):
      var fname = "fVal"
      add result, rhtBranch("ntFloat", op, fname)
      add result, rhtBranch("ntInt", op, fname, toFloatNode("rht", "iVal"))
      add result, rhtBranch("ntCall", op, fname, rhtCall(fname))
      add result, rhtBranchRec("ntCallStack", op)
    elif eqIdent(lident, "ntCall"):
      add result, getDefaultCallableCase()
      add result, getCallRec()
      add result, rhtBranchRec("ntCallStack", op)
    elif eqIdent(lident, "ntCallStack"):
      add result, getDefaultCallableCase()
      add result, getCallRec()
      add result, rhtBranchRec("ntCallStack", op)
    elif eqIdent(lident, "ntColor"):
      var fname = "getColor"
      add result, rhtBranch("ntColor", op, fname)
    add result, nnkElse.newTree(ident("false"))
  var
    evalBody = newNimNode(nnkReturnStmt)
    caseStmt = newNimNode(nnkCaseStmt)
  caseStmt.add(ident("infixOp"))
  for infixOperator in [EQ, NE, LT, LTE, GT, GTE, AND, OR]:
    var
      caseBranch = newNimNode(nnkOfBranch)
      lhtCase = newNimNode(nnkCaseStmt)
      rhtCase = newNimNode(nnkCaseStmt)
      rhtBranch = newNimNode(nnkOfBranch)
    if infixOperator in {EQ, NE}:
      lhtCase.add(newDotExpr(ident("lht"), ident("nt")))
      for lident in ["ntInt", "ntFloat", "ntString", "ntBool", "ntColor", "ntCall", "ntCallStack"]:
        var lhtBranch = newNimNode(nnkOfBranch)
        var lhtStmt = newStmtList()
        if lident == "ntCallStack":
          add lhtStmt,
            newVarStmt(
              ident("lht"),
              newcall(ident("handleCallStack"), ident("c"), ident("lht"), ident("scope"))
            )
        elif lident == "ntCall":
          add lhtStmt,
            newVarStmt(
              ident("lht"),
              newCall(ident("call"), ident("lht"), ident("scope"))
            )
        add lhtStmt, rhtCaseHandler(ident(lident), $(infixOperator))
        lhtBranch.add(
          ident(lident),
          lhtStmt
        )
        lhtCase.add(lhtBranch)
      add lhtCase, nnkElse.newTree(ident("false"))
      add caseBranch, ident(infixOperator.symbolName), lhtCase
    elif infixOperator in {LT, LTE, GT, GTE}:
      lhtCase.add(newDotExpr(ident("lht"), ident("nt")))
      for lident in ["ntInt", "ntFloat", "ntCall", "ntCallStack"]:
        var lhtBranch = newNimNode(nnkOfBranch)
        var lhtStmt = newStmtList()
        if lident == "ntCall":
          add lhtStmt,
            newVarStmt(
              ident("lht"),
              newCall(ident("call"), ident("lht"), ident("scope"))
            )
        add lhtStmt, rhtCaseHandler(ident(lident), $(infixOperator))
        lhtBranch.add(
          ident(lident),
          lhtStmt
        )
        lhtCase.add(lhtBranch)
      add lhtCase, nnkElse.newTree(ident("false"))
      add caseBranch, ident(infixOperator.symbolName), lhtCase
    else:
      caseBranch.add(
        ident(infixOperator.symbolName),
        ident("false")
      )
    caseStmt.add(caseBranch)
  add caseStmt, nnkElse.newTree(ident("false"))
  evalBody.add(caseStmt)
  result = newStmtList()
  result.add(
    newProc(
      ident("evalInfix"),
      [
        ident("bool"),
        newIdentDefs(
          ident("c"),
          nnkVarTy.newTree(ident("Compiler")),
          newEmptyNode()
        ),
        nnkIdentDefs.newTree(ident("lht"), ident("rht"), ident("Node"), newEmptyNode()),
        newIdentDefs(ident("infixOp"), ident("InfixOp"), newEmptyNode()),
        newIdentDefs(ident("scope"), ident("ScopeTable"), newEmptyNode()),
      ],
      evalBody
    )
  )
  # echo result.repr # debug

genInfixEval()