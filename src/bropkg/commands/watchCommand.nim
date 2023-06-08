# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[times, os, strutils, threadpool]
import pkg/watchout
import pkg/kapsis/[runtime, cli]

import ../engine/[parser, compiler, freemem]

proc runProgram(fpath, fname, cssPath: string) {.thread.} =
  {.gcsafe.}:
    let t = cpuTime()
    var p = parser.parseProgram(fpath)
    for warning in p.logger.warnings:
      display(warning)
    if p.hasErrors:
      for error in p.logger.errors:
        display(error)
    else:
      display(fname, indent = 3)
      # let cssPath = fpath.changeFileExt("css")
      var c = newCompiler(p.getProgram, cssPath)
      if cssPath.len != 0:
        writeFile(cssPath, c.getCSS)
      else:
        display(c.getCSS)
      display("Done in " & $(cpuTime() - t), br="before")
      freem(c)
    freem(p)

proc runCommand*(v: Values) =
  var stylesheetPath: string
  var cssPath: string
  var hasOutput = v.has("output")
  if v.has("style"):
    stylesheetPath = v.get("style").absolutePath()
    if not stylesheetPath.fileExists:
      display("Stylesheet does not exists")
      QuitFailure.quit
  else:
    QuitFailure.quit

  if hasOutput:
    cssPath = v.get("output")
    if cssPath.splitFile.ext != ".css":
      display("Output path missing `.css` extension\n" & cssPath)
      QuitFailure.quit
    if not cssPath.isAbsolute:
      cssPath.normalizePath
      cssPath = cssPath.absolutePath()

  var delay = 550
  if v.has("delay"):
    try:
      delay = parseInt v.get("delay")
    except ValueError:
      display("Invalid number for `delay`")
      QuitFailure.quit

  display "✨ Watching for changes...", br="after"
  var watchFiles: seq[string]
  proc watchoutCallback(file: watchout.File) {.closure.} =
    display "✨ Changes detected"
    if stylesheetPath.getFileSize > 0:
      spawn(runProgram(file.getPath, file.getName(), cssPath))
    else:
      display("Stylesheet is empty")

  watchFiles.add(stylesheetPath)
  spawn(runProgram(stylesheetPath, v.get("style"), cssPath))
  sync()
  startThread(watchoutCallback, watchFiles, delay, shouldJoinThread = true)
  QuitSuccess.quit