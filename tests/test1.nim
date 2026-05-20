import unittest
import pkg/openparser/json
import pkg/vancode/interpreter/ast

import ../src/bro
import ../src/bro/engine/parser

test "parse basic css":
  let sample = """
.my-class {
  color: red;
  font-size: 16px;
  background-size: cover;
}
"""
  var ast: Ast
  parser.parseScript(ast, sample, "test1.css")
  assert ast.nodes.len == 1
  assert ast.nodes[0].kind == nkClassSelector
  assert ast.nodes[0].children[0].ident == "my-class"
  assert ast.nodes[0].children[^1].kind == nkBlocK
  for x in ast.nodes[0].children[^1]:
    assert x.kind == nkColon # expression
    if x[0].ident == "color":
      assert x[1].ident == "red"
    elif x[0].ident == "font-size":
      assert x[1].kind == nkUnit
      assert x[1][0].intVal == 16
      assert x[1][1].ident == "px"
    elif x[0].ident == "background-size":
      assert x[1].ident == "cover"