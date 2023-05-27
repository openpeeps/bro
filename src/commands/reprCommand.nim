# Bro aka NimSass
# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro

import std/[times, os, strutils]
import pkg/yacli/[runtime, cli]
import pkg/[msgpack4nim, msgpack4nim/msgpack4collection]
import ../bro/[ast, compiler]

proc runCommand*(v: Values) =
  var astPath: string
  if v.has("ast"):
    astPath = v.get("ast").absolutePath()
    if not astPath.fileExists:
      display("Stylesheet does not exists")
      QuitFailure.quit
  else:
    QuitFailure.quit

  if astPath.getFileSize == 0:
    display("AST is empty")
    QuitFailure.quit
  display("✨ Building Stylesheet from AST...", br="after")
  let t = cpuTime()
  # if v.has("bson"):
  #   let
  #     astContent = newBsonDocument(readFile(astPath))
  #     astStruct = fromJson(astContent["ast"], Program)
  #   newCompiler(astStruct, astPath.changeFileExt("css"), minify = v.flag("minify"))
  # else:
  var astStruct: Program
  unpack(readFile(astPath), astStruct)
  newCompiler(astStruct, astPath.changeFileExt("css"), minify = v.flag("minify"))
  display "Done in " & $(cpuTime() - t)
  QuitSuccess.quit