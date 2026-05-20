# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/tim

import std/os
import pkg/voodoo/extensibles
import pkg/openparser/json

block extendAST:
  extendEnum NodeKind:
    nkClassSelector
    nkIdSelector
    nkUnit
    nkExprList
    nkProperty  # Represents a CSS property (e.g., color: red)
    nkValue     # Represents a CSS value (e.g., 16px, red)

block extendCodeGen:

  extendModule "vancode" / "interpreter" / "codegen.nim":
    
    proc genCssClass*(node: Node): Sym {.codegen.} =
      ## Generate bytecode for a CSS class selector
      assert node.kind == nkClassSelector, "Expected nkClassSelector node"

      # Push the class name
      gen.chunk.emit(opcPushClassSelector)
      gen.chunk.emit(gen.chunk.getString(node[0].ident))

      # Generate object storage for properties
      result = newType(ttyObject, name = node[0], impl = node)
      for prop in node[3].children:
        let key =
          if prop[0].kind == nkIdent: prop[0].ident
          elif prop[0].kind == nkString: prop[0].stringVal
          else: prop[0].error("Invalid property key: " & $prop[0].kind); ""

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
      let unitStr = $(node[0].intVal) & node[1].ident
      gen.chunk.emit(opcPushValue)
      gen.chunk.emit(gen.chunk.getString(unitStr))

  extendCaseStmt "codeGenExpr":
    case node.kind
    of nkUnit: discard gen.genUnit(node)

  extendCaseStmt "codeGenStmt":
    case node.kind
    of nkClassSelector:
      discard gen.genCssClass(node)
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
    opcPushClassSelector  # Push a class selector onto the stack
    opcPushProperty       # Push a CSS property
    opcPushValue          # Push a CSS value
    opcEmitCSS            # Emit the final CSS

  injectSnippet "VanCodeVMBeforeMainLoop":
    # a Voodoo injected snippet to initialize the `result` variable
    result = initValue("")

  extendCaseStmt "vmParseChunkCase":
    case oc:
    of opcPushClassSelector, opcPushProperty, opcPushValue:
      let sid = readArg[uint16](pc)
      addOp(oc, sid.int64, 0, akString)

  extendCaseStmt "vmInterpretCase":
    case oc:
    of opcPushClassSelector:
      let className = co.getArg1Str(pcIdx, currentChunk)
      stack.push(initValue(className))
    of opcPushValue:
      let valueStr = co.getArg1Str(pcIdx, currentChunk)
      stack.push(initValue(valueStr))
    of opcEmitCSS:
      let props = stack.pop().objectVal
      let keys = props.keys
      let className = stack.pop().stringVal[]
      result.stringVal[].add("." & className & "{")
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

when isMainModule:
  # Building Bro as a CLI application
  import pkg/kapsis
  import pkg/kapsis/[runtime, cli]
  import ./bro/app/build

  initKapsis do:
    defaultCommand: "compile"
    commands:
      compile path(source):
        ## Build CSS from BASS files