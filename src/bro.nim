# Bro aka NimSass
# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro

when compileOption("app", "lib"):
  import bro/[parser, compiler]

  proc compile*(stylesheetPath: cstring): cstring {.stdcall, exportc, dynlib.} =
    var p = parser.parseProgram($stylesheetPath)
    let c = newCompiler(p.getProgram(), p.getMemtable())
    return c.getCss.cstring

elif compileOption("app", "console"):
  import klymene/commands
  import commands/[watchCommand, buildCommand, mapCommand, astCommand]

  App:
    about:
      "😋 Bro aka NimSass - A super fast stylesheet language for cool kids!"
      "   https://github.com/openpeep/bro"
    commands:
      $ "build" `style`:
        ? "Transpiles the given stylesheet to CSS"
      --- "Development"
      $ "watch" `style` `delay`:
        ? "Watch for changes and transpile the given stylesheet to CSS"
      $ "map" `style`:
        ? "Generates a source map for the given stylesheet"
      $ "ast" `style`:
        ? "Generates AST for the given stylesheet"
else:
  import bro/[parser, compiler]
  export parser, compiler