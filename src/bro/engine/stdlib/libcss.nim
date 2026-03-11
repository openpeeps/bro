# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[strutils, options, base64]
import pkg/chroma
import pkg/voodoo/language/[chunk, ast, sym, value]

import ./inliner

type
  CSSValueError* = object of CatchableError

proc initCSS*(script: Script, systemModule: Module): Module =
  # foreign stuff
  result = newModule("css", some"std::css")
  result.load(systemModule)

  #
  # CSS Functions
  #
  script.addProc(result, "url", @[paramDef("s", ttyString)], ttyString,
    proc (args: StackView): Value =
      if args[0].stringVal[].len > 0:
        args[0]
      else:
        raise newException(CSSValueError, "URL cannot be empty.")
  )

  const defaultGlobalValues = ["inherit", "initial", "revert", "revert-layer", "unset"]

  #
  # CSS Properties
  #
  script.addProc(result, "background-color", @[paramDef("s", ttyString)], ttyString,
    proc (args: StackView): Value =
      discard parseHtmlColor(args[0].stringVal[])
      args[0]
  )

  script.addProc(result, "background-image", @[paramDef("s", ttyString)], ttyString,
    proc (args: StackView): Value =
      args[0]
  )

  script.addProc(result, "background-origin", @[paramDef("s", ttyString)], ttyString,
    proc (args: StackView): Value =
      if args[0].stringVal[] in ["border-box", "padding-box", "content-box"] or
          args[0].stringVal[] in defaultGlobalValues:
        args[0]
      else:
        raise newException(CSSValueError,
          "Invalid value for background-origin: " & args[0].stringVal[])
  )

  script.addProc(result, "background-position-x", @[paramDef("s", ttyString)], ttyString,
    proc (args: StackView): Value =
      args[0]
  )


  script.addProc(result, "background-position-y", @[paramDef("s", ttyString)], ttyString,
    proc (args: StackView): Value =
      args[0]
  )

  script.addProc(result, "background-position", @[paramDef("x", ttyString), paramDef("y", ttyString)], ttyString,
    proc (args: StackView): Value =
      initValue(args[0].stringVal[] & " " & args[1].stringVal[])
  )

  script.addProc(result, "background-repeat", @[paramDef("s", ttyString)], ttyString,
    proc (args: StackView): Value =
      if args[0].stringVal[] in ["repeat", "repeat-x", "repeat-y", "no-repeat"] or
          args[0].stringVal[] in defaultGlobalValues:
        args[0]
      else:
        raise newException(CSSValueError,
          "Invalid value for background-repeat: " & args[0].stringVal[])
  )

  script.addProc(result, "color", @[paramDef("s", ttyString)], ttyString,
    proc (args: StackView): Value =
      discard parseHtmlColor(args[0].stringVal[])
      args[0]
  )