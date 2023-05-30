import std/[os, strutils, unittest]
import bro

proc path(append: string): string =
  result = getCurrentDir() / "tests/stylesheets" / append

let
  basicsPath = path "basic.bass"
  invalidPath = path "invalid.bass"
  forPath = path "for.bass"
  forJsonPath = path "forjson.bass"

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

test "can compile `for` blocks":
  var p: Parser = parseProgram(forPath)
  check p.hasErrors == false
  check p.hasWarnings == false
  let c = newCompiler(p.getProgram, basicsPath)
  echo c.getCSS

test "can compile `for` blocks w/ @json":
  var p: Parser = parseProgram(forJsonPath)
  check p.hasErrors == false
  check p.hasWarnings == false
  let c = newCompiler(p.getProgram, basicsPath)
  echo c.getCSS