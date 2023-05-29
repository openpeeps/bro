# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

from ./tokens import TokenTuple
import std/[sequtils, strutils]

when compileOption("app", "console"):
  import pkg/kapsis/cli

type
  Level* = enum
    lvlInfo
    lvlNotice
    lvlWarn
    lvlError

  Log* = ref object
    msg, extraLabel: string
    line, col: int
    useFmt: bool
    args, extraLines: seq[string]

  Logger* = ref object
    filePath*: string
    infoLogs*, noticeLogs*, warnLogs*, errorLogs*: seq[Log]

proc add(logger: Logger, lvl: Level, msg: string,
                line, col: int, useFmt: bool, args: varargs[string]) =
  let log = Log(msg: msg, args: args.toSeq(),
                line: line, col: col + 1, useFmt: useFmt)
  case lvl:
    of lvlInfo:
      logger.infoLogs.add(log)
    of lvlNotice:
      logger.noticeLogs.add(log)
    of lvlWarn:
      logger.warnLogs.add(log)
    of lvlError:
      logger.errorLogs.add(log)

proc add(logger: Logger, lvl: Level, msg: string,
                line, col: int, useFmt: bool,
                extraLines: seq[string], extraLabel: string, args: varargs[string]) =
  let log = Log(
    msg: msg,
    args: args.toSeq(),
    line: line,
    col: col,
    useFmt: useFmt,
    extraLines: extraLines,
    extraLabel: extraLabel
  )
  case lvl:
    of lvlInfo:
      logger.infoLogs.add(log)
    of lvlNotice:
      logger.noticeLogs.add(log)
    of lvlWarn:
      logger.warnLogs.add(log)
    of lvlError:
      logger.errorLogs.add(log)

proc newInfo*(logger: Logger, msg: string, line, col: int,
              useFmt: bool, args:varargs[string]) =
  logger.add(lvlInfo, msg, line, col, useFmt, args)

proc newNotice*(logger: Logger, msg: string, line, col: int,
                useFmt: bool, args:varargs[string]) =
  logger.add(lvlNotice, msg, line, col, useFmt, args)

proc newWarn*(logger: Logger, msg: string, line, col: int,
              useFmt: bool, args:varargs[string]) =
  logger.add(lvlWarn, msg, line, col, useFmt, args)

proc newError*(logger: Logger, msg: string, line, col: int,
              useFmt: bool, args:varargs[string]) =
  logger.add(lvlError, msg, line, col, useFmt, args)

proc newErrorMultiLines*(logger: Logger, msg: string, line, col: int,
              useFmt: bool, extraLines: seq[string],
              extraLabel: string, args:varargs[string]) =
  logger.add(lvlError, msg, line, col, useFmt,
            extraLines, extraLabel, args)

template warn*(msg: string, tk: TokenTuple, args: varargs[string]) =
  let pos = if tk.pos == 0: 0 else: tk.pos + 1
  p.logger.newWarn(msg, tk.line, pos, false, args)

template warn*(msg: string, tk: TokenTuple, strFmt: bool, args: varargs[string]) =
  let pos = if tk.pos == 0: 0 else: tk.pos + 1
  p.logger.newWarn(msg, tk.line, pos, true, args)  

proc warn*(logger: Logger, msg: string, line, col: int, args: varargs[string]) =
  logger.add(lvlWarn, msg, line, col, false, args)

template error*(msg: string, tk: TokenTuple, args: varargs[string]) =
  let pos = if tk.pos == 0: 0 else: tk.pos + 1
  p.logger.newError(msg, tk.line, pos, false, args)
  p.hasErrors = true
  return # block code exection

template error*(msg: string, tk: TokenTuple, strFmt: bool,
            extraLines: seq[string], extraLabel: string,
            args: varargs[string]) =
  let pos = if tk.pos == 0: 0 else: tk.pos + 1
  newErrorMultiLines(
    p.logger, msg, tk.line, pos, strFmt,
    extraLines, extraLabel, args)
  p.hasErrors = true
  return # block code exection

template error*(msg: string, tk: TokenTuple, strFmt: bool, args: varargs[string]) =
  let pos = if tk.pos == 0: 0 else: tk.pos + 1
  p.logger.newError(msg, tk.line, pos, true, args)
  p.hasErrors = true
  return # block code exection

proc error*(logger: Logger, msg: string, line, col: int, args: varargs[string]) =
  logger.add(lvlError, msg, line, col, false, args)

proc runIterator(i: Log, label: string, fgColor: ForegroundColor): Row =
  add result, span(label, fgColor, indentSize = 0)
  add result, span("(" & $i.line & ":" & $i.col & ")")
  if i.useFmt:
    var x: int
    var str = i.msg.split("$")
    let length = i.msg.count("$") - 1
    for s in str:
      add result, span(s.strip())
      if length >= x:
        add result, span(i.args[x], fgBlue)
      inc x
  else:
    add result, span(i.msg)
    for a in i.args:
      add result, span(a, fgBlue)

when compileOption("app", "console"):
  iterator warnings*(logger: Logger): Row =
    for i in logger.warnLogs:
      yield runIterator(i, "Warning", fgYellow)

  iterator errors*(logger: Logger): Row =
    for i in logger.errorLogs:
      yield runIterator(i, "Error", fgRed)
      if i.extraLines.len != 0:
        if i.extraLabel.len != 0:
          var extraLabel: Row
          extraLabel.add(span(i.extraLabel, indentSize = 6))
          yield extraLabel
        for extraLine in i.extraLines:
          var extra: Row
          extra.add(span(extraLine, indentSize = 12))
          yield extra
