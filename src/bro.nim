# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/tim

import std/json

import pkg/voodoo/extensibles
import pkg/jsony

block extendVoodooAstAndCodeGen:
  extendEnum NodeKind:
    nkClassSelector
    nkIdSelector
    nkUnit

  extendCaseStmt "codeGenStmt":
    case node.kind
    of nkClassSelector:
      for n in node[3].children:
        echo "codeGenStmt nkClassSelector: ", n.kind
    of nkIdSelector:
      discard
    of nkUnit:
      echo "codeGenStmt: nkUnit"

  # vm
  # extendableCase "vmParseChunkCase":
  #   case oc
  #   of opc

when isMainModule:
  # Building Bro as a CLI application
  import pkg/kapsis
  import pkg/kapsis/[runtime, cli]
  import ./bro/app/build

  commands:
    css path(`in`):
      ## Build CSS from Bro files