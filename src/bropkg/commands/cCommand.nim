# A super fast stylesheet language for cool kids
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

  var cssPath: string
  var hasOutput = v.has("output")
  if hasOutput:
    cssPath = v.get("output")
    if cssPath.splitFile.ext != ".css":
      display("Output path missing `.css` extension\n" & cssPath)
      QuitFailure.quit
    if not cssPath.isAbsolute:
      cssPath.normalizePath
      cssPath = cssPath.absolutePath()
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
    QuitFailure.quit

  let c = newCompiler(p.getProgram, minify = v.flag("min"))
  if hasOutput:
    if v.flag("gzip"):
      writeFile(cssPath.changeFileExt(".css.gzip"), compress(c.getCSS, dataFormat = dfGzip))
    else:
      writeFile(cssPath, c.getCSS)
  else:
    display(c.getCSS)
  if hasOutput:
    display "Done in " & $(cpuTime() - t)
  QuitSuccess.quit