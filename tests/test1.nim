import std/[os, strutils, unittest]
import bro

proc getPath(append: string): string =
  result = getCurrentDir() / "tests/stylesheets" / append & ".bass"

var paths = ["basic", "invalid", "for", "json", "case", "unused", "vars"]
var stdlib = ["colors", "strings"]

test "can parse":
  var p = parseStylesheet(paths[0].getPath().readFile, paths[0].getPath())
  check p.hasErrors == false
  check p.hasWarnings == false

test "can compile":
  let basic = paths[0].getPath()
  echo readFile(basic)
  var p = parseStylesheet(readFile(basic), basic)
  check p.hasErrors == false
  check p.hasWarnings == false

  var c: Compiler
  # unminified
  c = newCompiler(p.getStylesheet)
  check c.getCSS.count("\n") == 3
  # minified
  c = newCompiler(p.getStylesheet, minify = true)
  check c.getCSS.count("\n") == 0
  check c.getCSS == ".btn{border:2px #FFFFFF solid}"

# test "can catch errors":
#   var p = parseStylesheet(readFile(paths[1].getPath), paths[1].getPath)
#   check p.hasErrors == true
#   check p.logger.errorLogs[0].getMessage == undeclaredVariable

# test "can catch warnings":
#   var p = parseStylesheet(paths[5].getPath.readFile, paths[5].getPath)
#   check p.hasErrors == false
#   check p.hasWarnings == true

test "var declarations":
  var p = parseStylesheet(paths[6].getPath.readFile, paths[6].getPath)
  check p.hasErrors == false
  var c = newCompiler(p.getStylesheet)
  echo c.getCSS

test "loops":
  var p = parseStylesheet(paths[2].getPath.readFile, paths[2].getPath())
  check p.hasErrors == false
  check p.hasWarnings == false
  let c = newCompiler(p.getStylesheet, imports = p.getStylesheets)
  echo c.getCSS

test "loops json":
  var p = parseStylesheet(paths[3].getPath.readFile, paths[3].getPath())
  check p.hasErrors == false
  check p.hasWarnings == false
  let c = newCompiler(p.getStylesheet, imports = p.getStylesheets)
  echo c.getCSS

test "std/colors":
  var src = getPath("test_colors")
  var p = parseStylesheet(src.readFile, src)
  check p.hasErrors == false
  check p.hasWarnings == false
  var c = newCompiler(p.getStylesheet, imports = p.getStylesheets)

test "std/arrays":
  var src = getPath("test_arrays")
  var p = parseStylesheet(src.readFile, src)
  check p.hasErrors == false
  check p.hasWarnings == false
  var c = newCompiler(p.getStylesheet, imports = p.getStylesheets)

test "std/os":
  var src = getPath("test_os")
  var p = parseStylesheet(src.readFile, src)
  check p.hasErrors == false
  check p.hasWarnings == false
  var c = newCompiler(p.getStylesheet, imports = p.getStylesheets)

test "std/string":
  var src = getPath("test_strings")
  var p = parseStylesheet(src.readFile, src)
  check p.hasErrors == false
  check p.hasWarnings == false
  var c = newCompiler(p.getStylesheet, imports = p.getStylesheets)

test "std/math":
  var src = getPath("test_math")
  var p = parseStylesheet(src.readFile, src)
  check p.hasErrors == false
  check p.hasWarnings == false
  var c = newCompiler(p.getStylesheet, imports = p.getStylesheets)

# test "`case` blocks":
#   let path = paths[4].getPath()
#   var p = parseStylesheet(path.readFile, path)
#   check p.hasErrors == false
#   check p.hasWarnings == false
#   let c = newCompiler(p.getStylesheet)
#   echo c.getCSS
