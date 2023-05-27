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
      let cssContent = newCompilerStr(p.getProgram, sourcePath)
      return %* cssContent
      # return napiCall("JSON.parse", [ %* "[]" ])

# elif compileOption("app", "lib"):
#   import bro/[parser, compiler]

#   proc compile*(stylesheetPath: cstring): cstring {.stdcall, exportc, dynlib.} =
#     var p = parser.parseProgram($stylesheetPath)
#     let c = newCompiler(p.getProgram(), p.getMemtable())
#     return c.getCss.cstring

elif compileOption("app", "console"):
  import yacli/commands
  import yacli/db
  import commands/[watchCommand, cCommand,
                  mapCommand, astCommand, docCommand, reprCommand]

  App:
    settings(
      database = dbMsgPacked, # enable flat file database via Klymene
      mainCmd = "c",          # set `c` command as main
    )

    about:
      "😋 Bro aka NimSass - A super fast stylesheet language for cool kids!"
      "   https://github.com/openpeep/bro"
    
    commands:
      $ "c" `style` ["minify", "map"]:
        ?         "Compiles a stylesheet to CSS"
        ? style   "Provide a stylesheet path"
        ? minify  ""
      
      --- "Development"
      $ "watch" `style` `delay`:
        ? "Watch for changes and compile"
      
      $ "map" `style`:
        ? "Generates a source map"
      
      $ "ast" `style`:
        ? "Generates a packed AST"
      
      $ "repr" `ast` ["minify"]:
        ? "Compiles packed AST to CSS"

      # --- "CSS"
      # $ "lint":
      #   ? "Performs a static analysis of "

      --- "Documentation"
      $ "doc" `style`:
        ? "Builds a documentation website"

else:
  import bro/[parser, compiler]
  export parser, compiler