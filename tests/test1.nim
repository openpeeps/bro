import std/[os, strutils, unittest]
import bro

let
  basicsPath = getCurrentDir() & "/tests/stylesheets/basic.bass"
  invalidPath = getCurrentDir() & "/tests/stylesheets/invalid.bass"

test "can parse":
  var p: Parser = parseProgram(basicsPath)
  check p.hasErrors == false
  check p.hasWarnings == false

test "can compile":
  var p: Parser = parseProgram(basicsPath)
  check p.hasErrors == false
  check p.hasWarnings == false

  var c: Compiler
  # unminified
  c = newCompiler(p.getProgram, basicsPath)
  check c.getCSS.count("\n") == 3
  # minified
  c = newCompiler(p.getProgram, basicsPath, minify = true)
  check c.getCSS.count("\n") == 0
  check c.getCSS == ".btn{border:2px #FFF solid}"

test "can catch errors":
  var p: Parser = parseProgram(invalidPath)
  check p.hasErrors == true
  check p.logger.errorLogs[0].getMessage == InvalidProperty
