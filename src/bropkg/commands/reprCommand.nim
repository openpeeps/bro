# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[times, os, strutils]
import ../engine/[ast, compiler]

import pkg/zippy
import pkg/kapsis/[runtime, cli]
import ../private/msgpack/[msgpack4nim, msgpack4nim/msgpack4collection]

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
  var astStruct: Program
  unpack(readFile(astPath), astStruct)
  let c = newCompiler(astStruct, astPath.changeFileExt("css"), minify = v.flag("minify"))
  if likely(not v.flag("gzip")):
    writeFile(astPath.changeFileExt("css"), c.getCSS)
  else:
    writeFile(astPath.changeFileExt(".css.gzip"), compress(c.getCSS, dataFormat = dfGzip))
  display "Done in " & $(cpuTime() - t)
  QuitSuccess.quit