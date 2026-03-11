# A super fast template engine for cool kids
#
# (c) iLiquid, 2019-2020
#     https://github.com/liquidev/
#
# (c) 2025 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/tim | https://openpeeps.dev/packages/tim

import std/[strutils, options, base64]
import pkg/voodoo/language/[chunk, codegen, ast, sym, value]

proc initEmails*(script: Script, systemModule: Module): Module =
  ## This module provides macros and functions for generating
  ## responsive email templates using the Tim template engine.
  result = newModule("emails", some"emails.timl")
  result.load(systemModule)

  script.addProc(result, "contains", @[paramDef("s", tyString), paramDef("sub", tyString)], tyBool,
    proc (args: StackView): Value =
      initValue(strutils.contains(args[0].stringVal[], args[1].stringVal[])))