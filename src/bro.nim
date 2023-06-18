# A super fast statically typed stylesheet language for cool kids
#
# (c) 2023 George Lemon | MIT License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro
when defined napibuild:
  import denim
  import bropkg/engine/[parser, compiler]
  from std/sequtils import toSeq

  init proc(module: Module) =
    module.registerFn(2, "compile"):
      if not Env.expect(args, "BroError", ("src", napi_string), ("minify", napi_boolean)):
        return
      let sourcePath = args[0].getStr
      var p = parseProgram(sourcePath)
      if not p.hasErrors:
        return %* newCompiler(p.getProgram, sourcePath).getCSS
      else:
        let errors = p.logger.errors.toSeq
        assert error($(errors[0]), "BroParsingError")
else:
  when isMainModule:
    import kapsis/commands
    import kapsis/db
    import bropkg/commands/[watchCommand, cCommand,
                    mapCommand, astCommand, docCommand, reprCommand]

    App:
      settings(
        database = dbMsgPacked, # enable flat file database via Klymene
        mainCmd = "c",          # set `c` command as main
      )

      about:
        "😋 Bro - A super fast stylesheet language for cool kids!"
        "   https://github.com/openpeeps/bro"
      
      commands:
        $ "c" `style` `output` ["min", "map", "gzip"]:
          ?         "Compiles a stylesheet to CSS"
          ? style   "A stylesheet path"
          ? min     "Output minified CSS code"
          ? gzip    "Compress CSS using gzip"
          ? stdout  "Return CSS to stdout"
        
        --- "Development"
        $ "watch" `style` `delay` `output`:
          ? "Watch for changes and compile"
        
        $ "map" `style`:
          ? "Generates a source map"
        
        $ "ast" `style` ["gzip"]:
          ? "Generates a packed AST"
        
        $ "repr" `ast` ["minify", "gzip"]:
          ? "Compiles packed AST to CSS"

        --- "Documentation"
        $ "doc" `style`:
          ? "Builds a documentation website"
  else:
    import bropkg/engine/[parser, compiler]
    export parser, compiler