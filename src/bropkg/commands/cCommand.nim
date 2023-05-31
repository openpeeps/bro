# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[times, os, strutils]
import pkg/kapsis/[runtime, cli]
import pkg/zippy

import ../engine/[parser, compiler]

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
  if not v.flag("stdout"):
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
    let c = newCompiler(p.getProgram, cssPath, minify = v.flag("minify"))
    if likely(not v.flag("gzip")):
      if not v.flag("stdout"):
        writeFile(cssPath, c.getCSS)
      else:
        display(c.getCSS)
    else:
      if not v.flag("stdout"):
        writeFile(cssPath.changeFileExt(".css.gzip"), compress(c.getCSS, dataFormat = dfGzip))
    if not v.flag("stdout"):
      display "Done in " & $(cpuTime() - t)
    QuitSuccess.quit