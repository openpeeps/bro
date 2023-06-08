import std/[os, strutils, unittest]
import bro

proc getPath(append: string): string =
  result = getCurrentDir() / "tests/stylesheets" / append & ".bass"

var paths = ["basic", "invalid", "for", "forjson", "case", "unused"]

test "can parse":
  var p = parseProgram(paths[0].getPath())
  check p.hasErrors == false
  check p.hasWarnings == false

test "can compile":
  let basic = paths[0].getPath()
  var p = parseProgram(basic)
  check p.hasErrors == false
  check p.hasWarnings == false

  var c: Compiler
  # unminified
  c = newCompiler(p.getProgram, basic)
  check c.getCSS.count("\n") == 3
  # minified
  c = newCompiler(p.getProgram, basic, minify = true)
  check c.getCSS.count("\n") == 0
  check c.getCSS == ".btn{border:2px #FFF solid}"

test "can catch errors":
  var p = parseProgram(paths[1].getPath)
  check p.hasErrors == true
  check p.logger.errorLogs[0].getMessage == InvalidProperty

test "can catch warnings":
  var p = parseProgram(paths[5].getPath)
  check p.hasErrors == false
  check p.hasWarnings == true

test "can compile `for` blocks":
  let path = paths[2].getPath()
  var p = parseProgram(path)
  check p.hasErrors == false
  check p.hasWarnings == false
  let c = newCompiler(p.getProgram, path)

test "can compile `for` blocks w/ @json":
  let path = paths[3].getPath()
  var p = parseProgram(path)
  check p.hasErrors == false
  check p.hasWarnings == false
  let c = newCompiler(p.getProgram, path)

test "can compile `case` blocks":
  let path = paths[4].getPath()
  var p = parseProgram(path)
  check p.hasErrors == false
  check p.hasWarnings == false
  let c = newCompiler(p.getProgram, path)
  echo c.getCSS