import std/[tables, json, jsonutils, strutils, macros, sequtils, os]
import ./staticparse

template generateMeta() =
  type
    Status* = enum
      NonStandard

    SyntaxChecker = proc(v: string): bool {.nimcall.}

    Property* = ref object
      syntax: TableRef[string, seq[SyntaxChecker]]
      inherited: bool
      initial: seq[string]
      status: Status
      refurl: string

    PropertiesTable = TableRef[string, Property]


proc newSyntaxProc(pIdent: string, body = newEmptyNode()): NimNode = 
  result = newProc(
    nnkPostfix.newTree(
      ident("*"),
      ident(pIdent)
    ),
    params = [
      ident("bool"),
      newIdentDefs(
        ident("v"),
        ident("string")
      )
    ],
    body = body
  )
  result.addPragma(ident("nimcall"))

var definedProcs {.compileTime.}: seq[string]


# dumpAstGen:
#   props["align-items"] = Property(
#     syntax: newTable({"a", @[""]}),
#     refurl: "https://asasdsa.com"
#   )

# dumpAstGen:
#   let spans = split(v, ' ')
#   if spans.len == 2:
#     if spans[0] in ["first", "last"] and spans[2] == "baseline":
#       return true
#   elif spans.len == 1:
#     return spans[0] == "baseline"

proc generateCode(formalSyntax: string): NimNode =
  echo formalSyntax
  var ifNode = newTree(nnkIfStmt)
  var litNodes = newTree(nnkBracket)
  var fnNodes: seq[NimNode]
  var body = newStmtList(
    nnkReturnStmt.newTree(
      ident("true")
    )
  )
  let program = parseSyntax(formalSyntax)
  echo program
  for node in program.nodes:
    case node.nt:
    of ntGroup:
      for n in node.group:
        case n.nt:
        of ntLiteral:
          litNodes.add(newLit(n.strIdent))
        of ntFunction:
          fnNodes.add(
            nnkElifBranch.newTree(
              newCall(
                ident(n.fnIdent),
                ident("v")
              ),
              newStmtList(
                nnkReturnStmt.newTree(
                  ident("true")
                )
              )
            )
          )
        else: discard
    of ntValue:
      for n in node.value:
        case n.nt:
        of ntLiteral:
          litNodes.add(newLit(n.strIdent))
        of ntInfix:
          let
            left = n.infixLeft
            right = n.infixRight
          if left.nt == ntGroup:
            for val in left.group:
              # echo val.strIdent
              litNodes.add(newLit(val.strIdent))
          echo right
        of ntFunction:
          fnNodes.add(
            nnkElifBranch.newTree(
              newCall(
                ident(n.fnIdent),
                ident("v")
              ),
              newStmtList(
                nnkReturnStmt.newTree(
                  ident("true")
                )
              )
            )
          )
        else: discard
    else: discard
  # create conditional statement for static values
  # such as 'left', 'center', 'right'
  if litNodes.len != 0:
    ifNode.add(
      nnkElifBranch.newTree(
        nnkInfix.newTree(
          ident("in"),
          ident("v"),
          litNodes
        ),
        body
      )
    )
  if fnNodes.len != 0:
    for fnNode in fnNodes:
      ifNode.add(fnNode)
  result = ifNode
  # echo result.repr

proc generateCode(node: JsonNode): NimNode =
  ## Generate code for string-based values
  var litNodes = newTree(nnkBracket)
  for n in node:
    litNodes.add(newLit(n["value"].getStr))
  result = newTree(nnkIfStmt)
  result.add(
    nnkElifBranch.newTree(
      nnkInfix.newTree(
        ident("in"),
        ident("v"),
        litNodes
      ),
      newStmtList(
        nnkReturnStmt.newTree(
          ident("true")
        )
      )
    )
  )

macro generateProperties() =
  result = newStmtList()
  result.add(
    newCommentStmtNode("""Bro aka NimSass
A super fast stylesheet language for cool kids.

Full list of CSS Properties and Values, parser grammar and other cool things.

Auto-generated at compile-time from MDN source:
https://github.com/mdn/data

(c) 2023 George Lemon | MIT License
         Made by Humans from OpenPeep
         https://github.com/openpeep/bro"""
    )
  )

  let
    basePath = getProjectPath() / "webref-main" / "ed" / "css"
    # specList = ["css-align", "css-anchor-position", "css-backgrounds-4", "css-anchor-position",
    #             "css-position", "css-sizing", "CSS", "motion"]
    specList = ["css-align"]

  var procFwds, procDefs: seq[NimNode]
  for spec in specList:
    let fileName = spec & ".json"
    var
      content = parseJSON(readFile(basePath / fileName))
      gValues = Table[string, seq[string]]()

    if content["values"].len == 0: continue
    let url = content["spec"]["url"].getStr
    for v in content["values"]:
      let pIdent = "check" & getProcName(v["name"].getStr)
      if pIdent notin definedProcs:
        add definedProcs, pIdent
      else: continue
      var
        syntaxCheckBody = newStmtList()
        validValues = nnkBracket.newTree()
        vComment: seq[string]
        hasValues: bool
        formalSyntax: string
      if v.hasKey("values"):
        syntaxCheckBody.add(
          newCommentStmtNode(
            "Available values:" &
              vComment.map(proc(x: string): string =
                            "`" & x & "`").join(", ").indent(1)
          )
        )
        for vv in v["values"]:
          let val = vv["value"].getStr
          add validValues, newLit(val)
          add vComment, vv["value"].getStr
        syntaxCheckBody.add(generateCode(v["values"]))
        procDefs.add(newSyntaxProc(pIdent, syntaxCheckBody))
      elif v.hasKey("value"):
        ## string based list of values
        hasValues = true
        formalSyntax = v["value"].getStr
        # parse formal syntax and generate Nim code
        let arrValues = v["value"].getStr.split("|")
                                  .map(proc(x: string): string = x.strip())
        for vv in arrValues:
          add validValues, newLit(vv)
          add vComment, vv
      if hasValues:
        syntaxCheckBody.add(
          newCommentStmtNode(
            "Available values:" &
              vComment.map(proc(x: string): string =
                            "`" & x & "`").join(", ").indent(1)
          )
        )
        syntaxCheckBody.add(generateCode(formalSyntax))
        procFwds.add(newSyntaxProc(pIdent))
        procDefs.add(newSyntaxProc(pIdent, syntaxCheckBody))
        hasValues = false

    # result.add(newCommentStmtNode("Generated from ed/css/" & fileName))
    for procFwd in procFwds:
      result.add(procFwd)
    for procDef in procDefs:
      result.add(procDef)
    setLen(procFwds, 0)
    setLen(procDefs, 0)

    # lets walk through all properties
    # and create a Property object for each
    result.add(newCommentStmtNode("Property validators"))
    for property in content["properties"]:
      let pIdent = "validate" & getProcName(property["name"].getStr)
      let propertyValueSyntax = property["value"].getStr
      let procBody = generateCode(propertyValueSyntax)
      procDefs.add(newSyntaxProc(pIdent, procBody))

      for procDef in procDefs:
        result.add(procDef)
      break

    # result.add(
    #   newAssignment(
    #     nnkBracketExpr.newTree(
    #       ident("props"),
    #       newLit(property["name"].getStr)
    #     ),
    #     nnkObjectConstr.newTree(
    #       ident("Property"),
    #       nnkExprColonExpr.newTree(
    #         ident("syntax"),
    #         newCall(
    #           ident("newTable")
    #           propertyCheckers
    #         )
    #       )
    #     )
    #   )
    # )
    # nnkAsgn.newTree(
    #   nnkBracketExpr.newTree(
    #     newIdentNode("props"),
    #     newLit("align-items")
    #   ),
    #   nnkObjConstr.newTree(
    #     newIdentNode("Property"),
    #     nnkExprColonExpr.newTree(
    #       newIdentNode("syntax"),
    #       nnkCall.newTree(
    #         newIdentNode("newTable"),
    #         nnkCurly.newTree(
    #           newLit("a"),
    #           nnkPrefix.newTree(
    #             newIdentNode("@"),
    #             nnkBracket.newTree(
    #               newLit("")
    #             )
    #           )
    #         )
    #       )
    #     ),
    #     nnkExprColonExpr.newTree(
    #       newIdentNode("refurl"),
    #       newLit("https://asasdsa.com")
    #     )
    #   )
    # )


      # var propObject = nnkObjConstr.newTree(ident("Property"))
      # propObject.add(
      #   nnkExprColonExpr.newTree(
      #     ident("values"),
      #     newCall(
      #       ident()
      #     )
      #   )
      # )
  echo result.repr

generateProperties()