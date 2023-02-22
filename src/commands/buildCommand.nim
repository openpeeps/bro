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
  display("✨ Building...", br="after")
  let
    t = cpuTime()
    p = parser.parseProgram(stylesheetPath)
  for warning in p.logger.warnings:
    display(warning)
  display(" 👉 " & stylesheetPath, br="after")

  if p.hasErrors:
    display("Build failed with errors")
    for error in p.logger.errors:
      display(error)
    display(" 👉 " & stylesheetPath)
  else:
  #   if p.hasWarnings:
  #     for warning in p.warnings:
  #       display(
  #         span("Warning", fgYellow),
  #         span("($1:$2):" % [$warning.line, $warning.col]),
  #         span("Declared and not used"),
  #         span("$1\n" % [warning.msg], fgBlue),
  #         span(stylesheetPath & "\n"),
  #       )
    newCompiler(p.getProgram(), p.getMemtable(), cssPath, minify = v.flag("minify"))
    display "Done in " & $(cpuTime() - t)
    QuitSuccess.quit