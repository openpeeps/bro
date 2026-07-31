# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/os
import pkg/voodoo/extensibles
import pkg/openparser/json
import pkg/openparser/css

import ./cssvalidator

block extendAST:
  extendEnum NodeKind:
    nkClassSelector
    nkIdSelector
    nkPseudoSelector
    nkElementSelector
    nkUnit
    nkExprList
    nkProperty  # Represents a CSS property (e.g., color: red)
    nkValue     # Represents a CSS value (e.g., 16px, red)
    nkAtRule    # Represents a CSS at-rule (e.g., @media, @supports)
    nkCommaList # Represents comma-separated CSS values (e.g., 13, 110, 253)

block extendSym:
  extendEnum TypeKind:
    ttyColor
    ttyLength
    ttyNumber
    ttyKeyword
    ttyAngle
    ttyTime
    ttyUrl
    ttyCssString
    ttyResolution
    ttyFlex
block extendCodeGen:
  extendModule "vancode" / "interpreter" / "codegen.nim":
    import pkg/openparser/css as cssmod

    let cssData = cssmod.loadCssData()

    proc parseCssValues(raw: string): seq[cssmod.CssValue] =
      let fakeCss = "*{x:" & raw & "}"
      let style = cssmod.parseCss(fakeCss)
      if style.nodes.len > 0 and style.nodes[0].kind == cssmod.cssRuleSet:
        if style.nodes[0].declarations.len > 0:
          result = style.nodes[0].declarations[0].valueComponents

    proc cssValidateProp(propName: string, rawValue: var string): string =
      let vals = parseCssValues(rawValue)
      var res = cssmod.validate(cssData, propName, vals)
      if not res.valid:
        # Try auto-appending px for bare numbers like "100" -> "100px"
        if rawValue.len > 0 and rawValue[0] in {'0'..'9', '-'} and not rawValue.contains({'a'..'z', 'A'..'Z', '%'}):
          let pxValue = rawValue & "px"
          let pxVals = parseCssValues(pxValue)
          let pxRes = cssmod.validate(cssData, propName, pxVals)
          if pxRes.valid:
            rawValue = pxValue
            res = pxRes
          else:
            res = pxRes
        if not res.valid:
          var expected = ""
          if cssData.properties.hasKey(propName):
            expected = cssData.properties[propName].syntax
          var msg = propName & ": got '" & rawValue & "'"
          if expected.len > 0:
            msg &= ", expected " & expected
          raise newException(ValueError, msg)
      let syn = cssmod.getPropertySyntax(cssData, propName)
      if syn == nil: return "keyword"
      case syn.kind
      of skType: result = syn.cssType
      else: result = "keyword"

    proc cssGetPropertySyntax(propName: string): cssmod.SyntaxNode =
      cssmod.getPropertySyntax(cssData, propName)

    proc cssTypeToKind(cssType: string): TypeKind =
      case cssType
      of "color": ttyColor
      of "length": ttyLength
      of "number", "integer": ttyNumber
      of "angle": ttyAngle
      of "time": ttyTime
      of "url": ttyUrl
      of "resolution": ttyResolution
      of "flex": ttyFlex
      of "string": ttyCssString
      else: ttyKeyword

    proc nodeToCssString(node: Node): string

    proc nodeToCssString(node: Node): string =
      case node.kind
      of nkIdent: result = node.ident
      of nkInt: result = $node.intVal
      of nkFloat: result = $node.floatVal
      of nkString:
        if node.stringVal.len > 0 and node.stringVal[0] == '#':
          result = node.stringVal # hex color literal, no quotes
        else:
          result = "\"" & node.stringVal & "\"" # string literal
      of nkUnit:
        result = if node[0].kind == nkInt: $node[0].intVal else: $node[0].floatVal
        result &= node[1].ident
      of nkExprList:
        var parts: seq[string]
        for child in node.children:
          parts.add(nodeToCssString(child))
        result = parts.join(" ")
      of nkCommaList:
        var cparts: seq[string]
        for child in node.children:
          cparts.add(nodeToCssString(child))
        result = cparts.join(", ")
      of nkCall:
        if node.children.len > 0 and node[0].kind == nkIdent:
          result = node[0].ident & "("
          var args: seq[string]
          for i in 1..<node.children.len:
            args.add(nodeToCssString(node[i]))
          result &= args.join(",") & ")"
      of nkInfix:
        if node.children.len >= 3:
          result = nodeToCssString(node[1]) & " " & nodeToCssString(node[0]) & " " & nodeToCssString(node[2])
      of nkPostfix:
        if node.children.len >= 2:
          result = nodeToCssString(node[1]) & " !" & node[0].ident
      else: result = ""

    proc genSelector*(node: Node): Sym {.codegen, discardable.} =
      ## Generate bytecode for a CSS selector (class, id, or pseudo)
      assert node.kind in {nkClassSelector, nkIdSelector, nkPseudoSelector, nkElementSelector}, "Expected selector node"

      let selectorType =
        case node.kind
        of nkClassSelector: 0'u16
        of nkIdSelector: 1'u16
        of nkPseudoSelector: 2'u16
        of nkElementSelector: 3'u16
        else: 0'u16

      # Push the selector name
      var selectorName: string
      case node[0].kind
      of nkIdent:
        selectorName = node[0].ident
      of nkBracket:
        for i, id in node[0].children:
          if id.kind == nkIdent:
            if i > 0: selectorName.add(",")
            selectorName.add(id.ident)
      else: node[0].error("Invalid selector name")
      gen.chunk.emit(opcPushSelector)
      gen.chunk.emit(gen.chunk.getString(selectorName))
      gen.chunk.emit(selectorType)

      # Generate object storage for properties
      result = newType(ttyObject, name = node[0], impl = node)
      var
        keyIdxes: seq[uint16]
        nestedStmts: seq[Node]
        hasDuplicate = false
      for child in node[3].children:
        if child.kind != nkColon:
          nestedStmts.add(child)
          continue
        let prop = child
        let key =
          if prop[0].kind == nkIdent: prop[0].ident
          elif prop[0].kind == nkString: prop[0].stringVal
          else: prop[0].error("Invalid property key: " & $prop[0].kind); ""

        # Duplicate property keys are allowed (e.g. vendor fallbacks like
        # `text-align: inherit; text-align: -webkit-match-parent;`).
        # Duplicates switch emission to raw mode so both declarations appear.
        if result.objectFields.hasKey(key):
          hasDuplicate = true
        let isVarRef = prop[1].kind == nkIdent and prop[1].ident.len > 0 and prop[1].ident[0] == '$'

        # Validate CSS property value for literal values
        if not isVarRef and prop[1].kind in {nkIdent, nkInt, nkFloat, nkString, nkUnit, nkExprList, nkCommaList, nkCall, nkPostfix}:
          var rawCss = nodeToCssString(prop[1])
          if rawCss.len > 0:
            # Validate the base value when `!important` is a postfix suffix
            var validateCss =
              if prop[1].kind == nkPostfix: nodeToCssString(prop[1][1])
              else: rawCss
            discard cssValidateProp(key, validateCss)
            let cssType = cssGetPropertySyntax(key)
            let expectedKind =
              if cssType != nil and cssType.kind == skType:
                cssTypeToKind(cssType.cssType)
              else:
                ttyKeyword
            keyIdxes.add(gen.chunk.getString(key))
            gen.chunk.emit(opcPushS)
            gen.chunk.emit(gen.chunk.getString(rawCss))
            let valTy = newType(expectedKind, name = prop[1])
            result.objectFields[key] = (
              id: result.objectFields.len,
              name: prop[0],
              ty: valTy,
              implVal: valTy
            )
            continue

        keyIdxes.add(gen.chunk.getString(key))
        let valTy =
          if isVarRef:
            gen.genExpr(prop[1])
          else:
            case prop[1].kind
            of nkIdent:
              gen.chunk.emit(opcPushS)
              gen.chunk.emit(gen.chunk.getString(prop[1].ident))
              newType(ttyString, name = prop[1])
            of nkInt:
              gen.chunk.emit(opcPushS)
              gen.chunk.emit(gen.chunk.getString($prop[1].intVal))
              newType(ttyString, name = prop[1])
            of nkFloat:
              gen.chunk.emit(opcPushS)
              gen.chunk.emit(gen.chunk.getString($prop[1].floatVal))
              newType(ttyString, name = prop[1])
            of nkString:
              gen.chunk.emit(opcPushS)
              gen.chunk.emit(gen.chunk.getString(prop[1].stringVal))
              newType(ttyString, name = prop[1])
            else:
              gen.genExpr(prop[1])
        result.objectFields[key] = (
          id: result.objectFields.len,
          name: prop[0],
          ty: valTy,
          implVal: valTy
        )

      # Only use raw nesting for at-rules (plain selectors stay at same level)
      var hasNestedAtRule = false
      for s in nestedStmts:
        if s.kind == nkAtRule:
          hasNestedAtRule = true
          break
      if hasNestedAtRule or hasDuplicate:
        let prefix =
          case selectorType
          of 0: "."
          of 1: "#"
          of 2: ":"
          else: ""
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString(prefix & selectorName & "{"))
        gen.chunk.emit(opcEmitRaw)
        gen.chunk.emit(uint16(node.ln))
        gen.chunk.emit(uint16(node.col))
        for child in node[3].children:
          if child.kind == nkColon:
            let key = child[0].ident
            let val = nodeToCssString(child[1])
            if val.len > 0:
              gen.chunk.emit(opcPushS)
              gen.chunk.emit(gen.chunk.getString(key & ":" & val & ";"))
              gen.chunk.emit(opcEmitRaw)
              gen.chunk.emit(uint16(child.ln))
              gen.chunk.emit(uint16(child.col))
        for stmt in nestedStmts:
          gen.genStmt(stmt)
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString("}"))
        gen.chunk.emit(opcEmitRaw)
        gen.chunk.emit(uint16(0xFFFF)) # no source mapping for closing brace
        gen.chunk.emit(uint16(0))
      else:
        gen.chunk.emit(opcConstrObj)
        gen.chunk.emit(uint16(result.objectFields.len))
        for kix in keyIdxes:
          gen.chunk.emit(kix)
        # opcEmitCSS carries: count, then selector (ln,col), then one (ln,col) per property
        var propCount = 0
        for child in node[3].children:
          if child.kind == nkColon:
            inc propCount
        gen.chunk.emit(opcEmitCSS)
        gen.chunk.emit(uint16(propCount + 1))
        gen.chunk.emit(uint16(node.ln))
        gen.chunk.emit(uint16(node.col))
        for child in node[3].children:
          if child.kind == nkColon:
            gen.chunk.emit(uint16(child.ln))
            gen.chunk.emit(uint16(child.col))
      # Emit non-at-rule nested selectors at the same level
      for stmt in nestedStmts:
        if stmt.kind != nkAtRule:
          gen.genStmt(stmt)

    proc genCssClass*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a CSS class selector
      result = gen.genSelector(node)

    proc genPseudoSelector*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a CSS pseudo-selector
      result = gen.genSelector(node)

    proc genCssProperty*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a CSS property
      assert node.kind == nkColon, "Expected nkColon node"

      # Push the property name
      gen.chunk.emit(opcPushProperty)
      gen.chunk.emit(gen.chunk.getString(node[0].ident))

      # Push the property value
      discard gen.genExpr(node[1])

    proc genUnit*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a CSS unit (e.g., 16px)
      assert node.kind == nkUnit, "Expected nkUnit node"

      # Push the unit value as a string (e.g., "16px")
      var size: string
      case node[0].kind
        of nkInt:
          size = $(node[0].intVal)
        of nkFloat:
          size = $(node[0].floatVal)
        else: node[0].error("Invalid unit value")

      let unitStr = size & node[1].ident
      gen.chunk.emit(opcPushValue)
      gen.chunk.emit(gen.chunk.getString(unitStr))

    proc genExprList*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a list of expressions (e.g., multiple properties)
      assert node.kind == nkExprList, "Expected nkExprList node"
      var parts: seq[string]
      for child in node.children:
        case child.kind
        of nkIdent: parts.add(child.ident)
        of nkInt: parts.add($child.intVal)
        of nkFloat: parts.add($child.floatVal)
        of nkString: parts.add(child.stringVal)
        of nkUnit:
          var v = if child[0].kind == nkInt: $child[0].intVal else: $child[0].floatVal
          parts.add(v & child[1].ident)
        else: parts.add("<value>")
      let combined = parts.join(" ")
      gen.chunk.emit(opcPushS)
      gen.chunk.emit(gen.chunk.getString(combined))
      result = newType(ttyString, name = node)

    proc genAtRule*(node: Node): Sym {.codegen.} =
      assert node.kind == nkAtRule, "Expected nkAtRule node"
      let name = node[0].ident
      var prelude = ""
      if node[1].kind == nkString and node[1].stringVal.len > 0:
        prelude = " " & node[1].stringVal
      if node[2].children.len > 0:
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString("@" & name & prelude & "{"))
        gen.chunk.emit(opcEmitRaw)
        gen.chunk.emit(uint16(node.ln))
        gen.chunk.emit(uint16(node.col))
        for child in node[2].children:
          if child.kind == nkColon:
            let key = child[0].ident
            let val = nodeToCssString(child[1])
            gen.chunk.emit(opcPushS)
            gen.chunk.emit(gen.chunk.getString(key & ":" & val & ";"))
            gen.chunk.emit(opcEmitRaw)
            gen.chunk.emit(uint16(child.ln))
            gen.chunk.emit(uint16(child.col))
          else:
            gen.genStmt(child)
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString("}"))
        gen.chunk.emit(opcEmitRaw)
        gen.chunk.emit(uint16(0xFFFF)) # no source mapping for closing brace
        gen.chunk.emit(uint16(0))
      else:
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString("@" & name & prelude & ";"))
        gen.chunk.emit(opcEmitRaw)
        gen.chunk.emit(uint16(node.ln))
        gen.chunk.emit(uint16(node.col))

  extendCaseStmt "codeGenExpr":
    case node.kind
    of nkUnit: discard gen.genUnit(node)
    of nkExprList: discard gen.genExprList(node)

  extendCaseStmt "codeGenStmt":
    case node.kind
    of nkClassSelector:
      discard gen.genCssClass(node)
    of nkPseudoSelector:
      discard gen.genPseudoSelector(node)
    of nkIdSelector:
      gen.genSelector(node)
    of nkElementSelector:
      gen.genSelector(node)
    of nkUnit:
      discard gen.genUnit(node)
    of nkExprList:
      discard
    of nkColon:
      discard gen.genCssProperty(node)
    of nkAtRule:
      discard gen.genAtRule(node)

block extendVM:
  extendEnum Opcode:
    opcPushSelector  # Push a class selector onto the stack
    opcPushProperty       # Push a CSS property
    opcPushValue          # Push a CSS value
    opcEmitCSS            # Emit the final CSS
    opcEmitRaw            # Emit a raw string directly to the output

  injectSnippet "VanCodeVMBeforeMainLoop":
    # a Voodoo injected snippet to initialize the `result` variable and the
    # source map segment accumulator (read back by the CLI after interpret)
    result = initValue("")
    vm.globals["__bro_sourcemap_segments"] = initValue("")

  extendCaseStmt "vmParseChunkCase":
    case oc:
    of opcPushSelector:
      # selector op has two args: string id, kind (uint16)
      let sid = readArg[uint16](pc)
      let kind = readArg[uint16](pc)
      addOp(oc, sid.int64, kind.int64, akString)
    of opcPushProperty, opcPushValue:
      let sid = readArg[uint16](pc)
      addOp(oc, sid.int64, 0, akString)
    of opcEmitRaw:
      # carries a source position (line, col) for source maps; 0xFFFF = no mapping
      let line = readArg[uint16](pc)
      let col = readArg[uint16](pc)
      addOp(oc, line.int64, col.int64, akInt)
    of opcEmitCSS:
      # carries a count followed by that many (line, col) position pairs,
      # stored in strKeys. First pair is the selector, rest are its properties.
      let cnt = readArg[uint16](pc).int
      addOp(oc, cnt.int64, 0, akInt)
      var poses: seq[uint16]
      for i in 0 ..< cnt:
        poses.add(readArg[uint16](pc))
        poses.add(readArg[uint16](pc))
      strKeys[^1] = poses

  extendCaseStmt "vmInterpretCase":
    case oc:
    of opcPushSelector:
      let className = co.getArg1Str(pcIdx, currentChunk)
      let kind = co.arg2[pcIdx].int
      stack.push(initValue(kind))
      stack.push(initValue(className))
    of opcPushValue:
      let valueStr = co.getArg1Str(pcIdx, currentChunk)
      stack.push(initValue(valueStr))
    of opcEmitRaw:
      let sl = co.getArg1Int(pcIdx)
      let sc = co.arg2[pcIdx].int
      if sl != 0xFFFF: # not a "no mapping" sentinel
        vm.globals["__bro_sourcemap_segments"].stringVal[].add(
          $result.stringVal[].len & "\x03" & $sl & "\x03" & $sc & "\x03" & currentChunk.file & "\x02")
      let rawStr = stack.pop().stringVal[]
      result.stringVal[].add(rawStr)
    of opcEmitCSS:
      let poses = co.strKeys[pcIdx]
      var pi = 0
      # selector mapping (first position pair)
      if poses.len >= 2:
        vm.globals["__bro_sourcemap_segments"].stringVal[].add(
          $result.stringVal[].len & "\x03" & $poses[pi] & "\x03" & $poses[pi + 1] & "\x03" & currentChunk.file & "\x02")
        pi += 2
      let props = stack.pop().objectVal
      let keys = props.keys
      let selectorName = stack.pop().stringVal[]
      let kind = stack.pop().intVal
      let prefix =
        case kind
        of 0: "." # class selector
        of 1: "#" # id selector
        of 2: ":" # pseudo-selector
        else: ""
      result.stringVal[].add(prefix & selectorName & "{")
      for i, key in keys:
        # per-property mapping
        if pi + 1 < poses.len:
          vm.globals["__bro_sourcemap_segments"].stringVal[].add(
            $result.stringVal[].len & "\x03" & $poses[pi] & "\x03" & $poses[pi + 1] & "\x03" & currentChunk.file & "\x02")
          pi += 2
        let val =
          case props.fields[i].typeId
          of tyString: props.fields[i].refVal.stringVal[]
          of tyInt:
            $(props.fields[i].intVal)
          of tyFloat:
            $(props.fields[i].floatVal)
          of tyBool:
            $(props.fields[i].boolVal)
          else: "<value>"

        result.stringVal[].add(key & ":" & val & ";")
      result.stringVal[].add("}")
