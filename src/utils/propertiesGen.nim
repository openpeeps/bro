import std/[tables, json, macros, strutils, os]

template propTypes() =
  import std/tables
  type
    Separator* = enum
      commaSep = ","
      spaceSep = " "

    Status* = enum
      Implemented
      NonStandard
      Unimplemented
      Experimental
      Obsolete
      Removed
      Deprecated

    Property* = ref object
      status: Status
      longhands: seq[string]
      values: TableRef[string, Status]
      url: string

    PropertiesTable = TableRef[string, Property]

  ## init `Properties`
  var Properties* = newTable[string, Property]()
  ## used to determine if given input
  ## is a valid CSS value 
  proc hasStrictValue*(prop: Property, key: string): tuple[exists: bool, status: Status] =
    if prop.values != nil:
      if prop.values.hasKey(key):
        result.exists = true
        result.status = prop.values[key]

macro initPropsTable() =
  let content = parseJSON(readFile(getProjectPath() / "CSSProperties.json"))["properties"]
  result = newStmtList()
  result.add(
    newCommentStmtNode("""Bro aka NimSass
A super fast stylesheet language for cool kids.

Full list of CSS Properties and Values, parser grammar and other cool things.

Auto-generated at Compile Time with Nim language from WebKit source:
https://github.com/WebKit/WebKit/blob/main/Source/WebCore/css/CSSProperties.json

(c) 2023 George Lemon | MIT License
         Made by Humans from OpenPeep
         https://github.com/openpeep/bro"""
    )
  )
  result.add getAst(propTypes())
  for k, p in content.pairs():
    var hasValues: bool
    var tableFields = nnkTableConstr.newTree()
    if p.hasKey("values"):
      hasValues = true
      for v in p["values"]:
        var status = "Implemented"
        var val: string
        if v.kind == JString:
          # prop.values[v.getStr] = Implemented
          val = v.getStr
        elif v.kind == JObject:
          if v.hasKey("status"):
            if v["status"].getStr == "non-standard":
              status = "NonStandard"
            elif v["status"].getStr == "obsolete":
              status = "Obsolete"
            elif v["status"].getStr == "experimental":
              status = "Experimental"
            elif v["status"].getStr == "unimplemented":
              status = "Unimplemented"
            elif v["status"].getStr == "removed":
              status = "Removed"
            elif v["status"].getStr == "deprecated":
              status = "Deprecated"
            else: discard
          # prop.values[v["value"].getStr] = status
          val = v["value"].getStr
        tableFields.add(
          nnkExprColonExpr.newTree(
            newLit(val),
            ident(status)
          )
        )

    var propObject = nnkObjConstr.newTree(ident("Property"))
    
    if p.hasKey("specification"):
      if p["specification"].hasKey("url"):
        propObject.add(
          nnkExprColonExpr.newTree(
            ident("url"),
            newLit(p["specification"]["url"].getStr)
          ),
        )
    
    if p.hasKey("codegen-properties"):
      if p["codegen-properties"].kind == JObject:
        if p["codegen-properties"].hasKey("longhands"):
          if p["codegen-properties"]["longhands"].len != 0:
            var seqN = newNimNode(nnkBracket) 
            for x in p["codegen-properties"]["longhands"]:
              seqN.add(newLit(x.getStr))
            propObject.add(
              nnkExprColonExpr.newTree(
                ident("longhands"),
                nnkPrefix.newTree(
                  ident("@"),
                  seqN
                )
              ),
            )
    if hasValues:
      propObject.add(
        nnkExprColonExpr.newTree(
          ident("values"),
          newCall(
            ident("newTable"),
            tableFields
          )
        )
      )

    result.add newCommentStmtNode("\nProperty `" & k & "`\n")
    result.add(
      newAssignment(
        nnkBracketExpr.newTree(
          ident("Properties"),
          newLit(k)
        ),
        propObject
      )
    )
  let code = result.repr.replace("`gensym1", "") # hack
  writeFile(getProjectPath() / ".." / "bro" / "properties.nim", code)

initPropsTable() # ignore undeclared identifier: 'Properties'