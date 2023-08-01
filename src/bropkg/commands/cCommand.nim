# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[times, os, strutils, monotimes]
import pkg/kapsis/[runtime, cli]
import pkg/zippy

import ../engine/[parser, compiler]

proc runCommand*(v: Values) =
  var
    cssPath: string
    hasOutput = v.has("output")
    stylesheetPath: string

  if v.has("style"):
    stylesheetPath = v.get("style").absolutePath()
    if not stylesheetPath.fileExists:
      display("Stylesheet does not exists")
      QuitFailure.quit
  else: QuitFailure.quit
  
  if stylesheetPath.getFileSize == 0:
    display("Stylesheet is empty")
    QuitFailure.quit
  
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
    t = getMonotime()
    p = parser.parseProgram(stylesheetPath)

  if unlikely(p.logger.warnLogs.len > 0):
    for warning in p.logger.warnings:
      display(warning)
    display(" 👉 " & stylesheetPath, br="after")

  if unlikely(p.hasErrors):
    # check for lexer/parser errors
    display("Build failed with errors")
    for error in p.logger.errors:
      display(error)
    display(" 👉 " & p.logger.filePath)
    QuitFailure.quit

  let c = newCompiler(p.getProgram, minify = v.flag("min"))
  if unlikely(c.hasErrors):
    # check for errors at compile time
    display("Build failed with errors")
    for error in c.logger.errors:
      display(error)
    display(" 👉 " & c.logger.filePath)
    QuitFailure.quit

  if hasOutput:
    if v.flag("gzip"):
      writeFile(cssPath.changeFileExt(".css.gzip"), compress(c.getCSS, dataFormat = dfGzip))
    else:
      writeFile(cssPath, c.getCSS)
  else:
    display(c.getCSS)
  if hasOutput:
    display("Done in " & $(getMonotime() - t))
  QuitSuccess.quit