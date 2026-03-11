import unittest

import pkg/jsony

import ../src/bro
import ../src/bro/engine/parser

import pkg/voodoo/language/ast

test "parse":
  let sample = """
.my-class {
  color: red;
}
"""
  var ast: Ast
  parser.parseScript(ast, sample, "test1.css")
  assert ast.nodes.len == 1
  assert ast.nodes[0].kind == nkClassSelector
  assert ast.nodes[0].children[0].ident == "my-class"
  assert ast.nodes[0].children[^1].kind == nkBlocK