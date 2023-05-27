# Bro aka NimSass
# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro

import std/[times, os, strutils]
import pkg/kapsis/[runtime, cli]
import pkg/zippy

import ../bro/[parser, compiler]

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
  if p.logger.warnLogs.len != 0:
    for warning in p.logger.warnings:
      display(warning)
    display(" 👉 " & stylesheetPath, br="after")

  if p.hasErrors:
    display("Build failed with errors")
    for error in p.logger.errors:
      display(error)
    display(" 👉 " & p.logger.filePath)
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
    let c = newCompiler(p.getProgram, cssPath, minify = v.flag("minify"))
    if likely(not v.flag("gzip")):
      writeFile(cssPath, c.getCSS)
    else:
      writeFile(cssPath.changeFileExt(".css.gzip"), compress(c.getCSS, dataFormat = dfGzip))
    display "Done in " & $(cpuTime() - t)
    QuitSuccess.quit