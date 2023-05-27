# Bro aka NimSass
# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro

import std/[times, os, strutils, threadpool]
import pkg/watchout
import pkg/kapsis/[runtime, cli]

import ../bro/[parser, compiler]

proc runProgram(fpath, fname: string) {.thread.} =
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
      let cssPath = fpath.changeFileExt("css")
      newCompiler(p.getProgram, cssPath)
      display("Done in " & $(cpuTime() - t), br="before")
    reset p

proc runCommand*(v: Values) =
  var stylesheetPath: string
  if v.has("style"):
    stylesheetPath = v.get("style").absolutePath()
    if not stylesheetPath.fileExists:
      display("Stylesheet does not exists")
      QuitFailure.quit
  else:
    QuitFailure.quit

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
      spawn(runProgram(file.getPath, file.getName()))
    else:
      display("Stylesheet is empty")

  watchFiles.add(stylesheetPath)
  spawn(runProgram(stylesheetPath, v.get("style")))
  sync()
  startThread(watchoutCallback, watchFiles, delay, shouldJoinThread = true)
  QuitSuccess.quit