import std/[times, os, strutils]
import pkg/klymene/[runtime, cli]

import ../bro/[parser, memtable, compiler]

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

  let cssPath = stylesheetPath.changeFileExt("css")
  display "✨ Building...", br="after"
  let
    t = cpuTime()
    p = parser.parseProgram(stylesheetPath)
  if p.hasError:
    display(p.getError, indent=3)
    # display("fname", br="after", indent = 3)
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
    newCompiler(p.getProgram(), p.getMemtable(), cssPath)
    display "Done in " & $(cpuTime() - t)
    QuitSuccess.quit