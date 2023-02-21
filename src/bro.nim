# Bro aka NimSass
# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeep
#          https://github.com/openpeep/bro

when defined napibuild:
  import denim/napi/napibindings
  import bro/[parser, compiler]

  init proc(module: Module) =
    module.registerFn(1, "compile"):
      let sourcePath = args[0].getStr
      var p = parseProgram(sourcePath)
      let cssContent = newCompilerStr(p.getProgram, p.getMemtable, sourcePath)
      return %* cssContent
      # return napiCall("JSON.parse", [ %* "[]" ])

# elif compileOption("app", "lib"):
#   import bro/[parser, compiler]

#   proc compile*(stylesheetPath: cstring): cstring {.stdcall, exportc, dynlib.} =
#     var p = parser.parseProgram($stylesheetPath)
#     let c = newCompiler(p.getProgram(), p.getMemtable())
#     return c.getCss.cstring

elif compileOption("app", "console"):
  import klymene/commands
  import commands/[watchCommand, buildCommand,
                  mapCommand, astCommand, docCommand]

  App:
    about:
      "😋 Bro aka NimSass - A super fast stylesheet language for cool kids!"
      "   https://github.com/openpeep/bro"
    commands:
      $ "build" `style` "--minify":
        ? "Transpiles the given stylesheet to CSS"
      
      --- "Development"
      $ "watch" `style` `delay`:
        ? "Watch for changes and transpile the given stylesheet into CSS"
      $ "map" `style`:
        ? "Generates a source map for the given stylesheet"
      $ "doc" `style`:
        ? "Builds a documentation website"
      $ "ast" `style`:
        ? "Generates Abstract Syntax Tree"

else:
  import bro/[parser, compiler]
  export parser, compiler