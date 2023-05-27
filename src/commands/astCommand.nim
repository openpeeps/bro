import std/[os, times, tables]

import pkg/yacli/[runtime, cli]
# import pkg/[jsony, bson]
import pkg/[msgpack4nim, msgpack4nim/msgpack4collection]

import ../bro/[parser, ast]

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

  display("✨ Building AST...", br="after")
  let
    t = cpuTime()
    p = parser.parseProgram(stylesheetPath)
  if p.hasError:
    for row in p.getError.rows:
      display(row)
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
    # if v.has("bson"):
    #     var doc = newBsonDocument()
    #     doc["ast"] = toJson(p.getProgram)
    #     try:
    #       writeFile(stylesheetPath.changeFileExt("bson"), doc.bytes)
    #     except IOError:
    #       display("Could not write JSON AST to file")
    #       QuitFailure.quit
    # else:
    var s = MsgStream.init()
    s.pack(p.getProgram)
    s.pack_bin(sizeof(p.getProgram))
    writeFile(stylesheetPath.changeFileExt("ast"), s.data)

    display "Done in " & $(cpuTime() - t)
    QuitSuccess.quit