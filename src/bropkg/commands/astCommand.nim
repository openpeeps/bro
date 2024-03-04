# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[os, times, tables]
import ../engine/[parser, ast]

import pkg/[flatty, supersnappy]
import pkg/kapsis/[runtime, cli]

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

  var outputPath = 
    if v.has("output"):
      v.get("output").absolutePath()
    else:
      stylesheetPath.changeFileExt("ast")

  display("✨ Building AST...", br="after")
  let
    t = cpuTime()
    p = parser.parseStylesheet(readFile(stylesheetPath), stylesheetPath)
  if p.hasErrors:
    display("Build failed with errors")
    for error in p.logger.errors:
      display(error)
    display(" 👉 " & p.logger.filePath)
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
    if not v.flag("plain"):
      writeFile(outputPath, toFlatty(p.getStylesheet).compress())
      display "Done in " & $(cpuTime() - t)
    else:
      display($p.getStylesheet)
    QuitSuccess.quit
