# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[times, os]
import ../engine/[ast, compiler]

import pkg/[flatty, supersnappy]
import pkg/kapsis/[runtime, cli]

proc runCommand*(v: Values) =
  ## Compiles binary AST to CSS
  # todo
  #   check if given path is really a valid .ast file
  #   store/check bro version 
  var astPath: string
  if v.has("ast"):
    astPath = v.get("ast").absolutePath()
    if not astPath.fileExists:
      display("Can't find AST file")
      QuitFailure.quit
  else:
    QuitFailure.quit

  if astPath.getFileSize == 0:
    display("AST is empty")
    QuitFailure.quit
  display("✨ Building Stylesheet from AST...", br="after")
  let t = cpuTime()
  var astStylesheet = uncompress(readFile(astPath)).fromFlatty(Stylesheet)
  let c = newCompiler(astStylesheet, minify = v.flag("minify"))
  writeFile(astPath.changeFileExt("css"), c.getCSS)
  display "Done in " & $(cpuTime() - t)
  QuitSuccess.quit