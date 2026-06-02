# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/os
import pkg/voodoo/extensibles
import pkg/openparser/json

block extendAST:
  extendEnum NodeKind:
    nkClassSelector
    nkIdSelector
    nkPseudoSelector
    nkUnit
    nkExprList
    nkProperty  # Represents a CSS property (e.g., color: red)
    nkValue     # Represents a CSS value (e.g., 16px, red)

block extendSym:
  extendEnum TypeKind:
    ttyColor  # Represents a color value (e.g., #ff0000, rgb(255, 0, 0))

block extendCodeGen:
  extendModule "vancode" / "interpreter" / "codegen.nim":
    proc genSelector*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a CSS selector (class, id, or pseudo)
      assert node.kind in {nkClassSelector, nkIdSelector, nkPseudoSelector}, "Expected selector node"

      let selectorType =
        case node.kind
        of nkClassSelector: 0'u16
        of nkIdSelector: 1'u16
        of nkPseudoSelector: 2'u16
        else: 0'u16

      # Push the selector name
      gen.chunk.emit(opcPushSelector)
      gen.chunk.emit(gen.chunk.getString(node[0].ident))
      gen.chunk.emit(selectorType)

      # Generate object storage for properties
      result = newType(ttyObject, name = node[0], impl = node)
      for prop in node[3].children:
        let key =
          if prop[0].kind == nkIdent: prop[0].ident
          elif prop[0].kind == nkString: prop[0].stringVal
          else: prop[0].error("Invalid property key: " & $prop[0].kind); ""

        if unlikely(result.objectFields.hasKey(key)):
          # actually, we should allow duplicate keys as CSS allows that and the last one wins
          # TODO handle this properly by allowing duplicates and using the last one, instead of just erroring out
          prop.error("Duplicate property key: " & key)

        # Push the key
        gen.chunk.emit(opcPushS)
        gen.chunk.emit(gen.chunk.getString(key))

        # Push the value
        let valTy = gen.genExpr(prop[1])
        result.objectFields[key] = (
          id: result.objectFields.len,
          name: prop[0],
          ty: valTy,
          implVal: valTy
        )

      # Emit the object storage for the properties
      gen.chunk.emit(opcConstrObj)
      gen.chunk.emit(uint16(result.objectFields.len))

      # Emit the CSS
      gen.chunk.emit(opcEmitCSS)

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
      debugEcho node

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
      discard
    of nkUnit:
      discard gen.genUnit(node)
    of nkExprList:
      discard
    of nkColon:
      discard gen.genCssProperty(node)

block extendVM:
  extendEnum Opcode:
    opcPushSelector  # Push a class selector onto the stack
    opcPushProperty       # Push a CSS property
    opcPushValue          # Push a CSS value
    opcEmitCSS            # Emit the final CSS

  injectSnippet "VanCodeVMBeforeMainLoop":
    # a Voodoo injected snippet to initialize the `result` variable
    result = initValue("")

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
    of opcEmitCSS:
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
        let val =
          case props.fields[i].typeId
          of tyString: props.fields[i].stringVal[]
          of tyInt:
            $(props.fields[i].intVal)
          of tyFloat:
            $(props.fields[i].floatVal)
          of tyBool:
            $(props.fields[i].boolVal)
          else: "<value>"

        result.stringVal[].add(key & ":" & val & ";")
      result.stringVal[].add("}")
