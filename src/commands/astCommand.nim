import std/[os, times]
import pkg/jsony
import pkg/klymene/[runtime, cli]

import ../bro/[parser]

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

  let astPath = stylesheetPath.changeFileExt("json")
  display "✨ Building AST...", br="after"
  let
    t = cpuTime()
    p = parser.parseProgram(stylesheetPath)
  if p.hasError:
    for row in p.getError.rows:
      display(row)
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
    try:
      writeFile(astPath, toJson(p.getProgram))
      display "Done in " & $(cpuTime() - t)
      QuitSuccess.quit
    except IOError:
      display("Could not write JSON AST to file")
      QuitFailure.quit