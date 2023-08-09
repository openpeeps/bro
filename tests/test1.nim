import std/[os, strutils, unittest]
import bro

proc getPath(append: string): string =
  result = getCurrentDir() / "tests/stylesheets" / append & ".bass"

var paths = ["basic", "invalid", "for", "forjson", "case", "unused", "vars"]

test "can parse":
  var p = parseStylesheet(paths[0].getPath())
  check p.hasErrors == false
  check p.hasWarnings == false

test "can compile":
  let basic = paths[0].getPath()
  var p = parseStylesheet(basic)
  check p.hasErrors == false
  check p.hasWarnings == false

  var c: Compiler
  # unminified
  c = newCompiler(p.getStylesheet)
  check c.getCSS.count("\n") == 3
  # minified
  c = newCompiler(p.getStylesheet, minify = true)
  check c.getCSS.count("\n") == 0
  check c.getCSS == ".btn{border:2px #FFF solid}"

test "can catch errors":
  var p = parseStylesheet(paths[1].getPath)
  check p.hasErrors == true
  check p.logger.errorLogs[0].getMessage == invalidProperty

test "can catch warnings":
  var p = parseStylesheet(paths[5].getPath)
  check p.hasErrors == false
  check p.hasWarnings == true

test "var declarations":
  var p = parseStylesheet(paths[6].getPath)
  check p.hasErrors == false
  var c = newCompiler(p.getStylesheet)
  echo c.getCSS

test "`for` blocks":
  let path = paths[2].getPath()
  var p = parseStylesheet(path)
  check p.hasErrors == false
  check p.hasWarnings == false
  let c = newCompiler(p.getStylesheet)
  echo c.getCSS

test "`for` blocks w/ @json":
  let path = paths[3].getPath()
  var p = parseStylesheet(path)
  check p.hasErrors == false
  check p.hasWarnings == false
  let c = newCompiler(p.getStylesheet)
  echo c.getCSS

test "`case` blocks":
  let path = paths[4].getPath()
  var p = parseStylesheet(path)
  check p.hasErrors == false
  check p.hasWarnings == false
  let c = newCompiler(p.getStylesheet)
  echo c.getCSS
