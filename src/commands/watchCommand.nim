import std/[times, os, strutils]
import pkg/watchout
import pkg/klymene/[runtime, cli]

import ../bro/[parser, memtable, compiler]

template runProgram(fpath, fname: string) =
  let t = cpuTime()
  var p = parser.parseProgram(fpath)
  if p.hasError:
    display(p.getError, indent=3)
    display fname, br="after", indent = 3
  else:
    display(fname, indent = 3)
    let cssPath = fpath.changeFileExt("css")
    newCompiler(p.getProgram, p.getMemtable, cssPath)
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
      runProgram(file.getPath, file.getName())
    else:
      display("Stylesheet is empty")

  watchFiles.add(stylesheetPath)
  startThread(watchoutCallback, watchFiles, delay, shouldJoinThread = true)
  QuitSuccess.quit