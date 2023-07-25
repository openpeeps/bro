# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[os, times, tables]
import ../engine/[parser, ast]

import pkg/zippy
import pkg/kapsis/[runtime, cli]
import ../private/msgpack/[msgpack4nim, msgpack4nim/msgpack4collection]

proc runCommand*(v: Values) =
  var stylesheetPath: string
  if v.has("style"):
    stylesheetPath = v.get("style").absolutePath()
    if not stylesheetPath.fileExists:
      display("Stylesheet does not exists")
      QuitFailure.quit
  else:
    QuitFailure.quit

  if stylesheetPath.getFileSize == 0:
    display("Stylesheet is empty")
    QuitFailure.quit

  display("✨ Building AST...", br="after")
  let
    t = cpuTime()
    p = parser.parseProgram(stylesheetPath)
  if p.hasError:
    for row in p.getError.rows:
      display(row)
    QuitFailure.quit
  else:
    if p.hasWarnings:
      for warning in p.warnings:
        display(
          span("Warning:", fgYellow),
          span("Declared and not used"),
          span("$1\n" % [warning.msg], fgBlue),
          span(stylesheetPath),
          span("($1:$2)\n" % [$warning.line, $warning.col]),
        )
    var s = MsgStream.init()
    s.pack(p.getProgram)
    s.pack_bin(sizeof(p.getProgram))
    if likely(v.flag("gzip")):
      writeFile(stylesheetPath.changeFileExt("ast.gzip"), compress(s.data, dataFormat = dfGzip))
    else:
      writeFile(stylesheetPath.changeFileExt("ast"), s.data)
    display "Done in " & $(cpuTime() - t)
    QuitSuccess.quit
