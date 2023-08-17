# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

when defined napibuild:
  # NAPI Build for Node.js and Bun.js
  import denim
  import bropkg/engine/[parser, compiler]
  from std/sequtils import toSeq

  init proc(module: Module) =
    proc toCSS(code: string, path: string, minify: bool) {.export_napi.} =
      var p = parseStylesheet(args.get("code").getStr, args.get("path").getStr)
      if not p.hasErrors:
        return %* newCompiler(p.getStylesheet, args.get("minify").getBool).getCSS()
      else:
        let errors = p.logger.errors.toSeq
        assert error($(errors[0]), "BroParsingError")
else:
  # CLI Application
  when isMainModule:
    import kapsis/commands
    import kapsis/db
    import bropkg/commands/[watchCommand, cCommand,
        mapCommand, astCommand, docCommand, reprCommand]

    App:
      settings(
        database = dbMsgPacked,
        mainCmd = "c",          # set `c` command as main
      )

      about:
        "😋 Bro - A super fast stylesheet language for cool kids!"
        "   https://github.com/openpeeps/bro"
      
      commands:
        $ "c" `style` `output` ["min", "map", "cache"]:
          ?         "Compiles a stylesheet to CSS"
          ? style   "A stylesheet path"
          ? min     "Output minified CSS code"
          ? map     "Build with Source Map"
          ? cache   "Enables binary AST Caching"
        
        --- "Development"
        $ "watch" `style` `output` `delay` ["sync", "min", "map"]:
          ? "Watch for changes and compile"
          ? style    "Your main .bass file"
          ? output   "Where to save the final CSS output"
          ? delay    "Delay in miliseconds (default 550)"
          ? sync     "Fast http server to handle CSS reload & browser syncing"
          ? map      "Build with Source Map"

        $ "map" `style`:
          ? "Generates a source map"
        
        $ "ast" `style` `output` ["plain"]:
          ? "Generates binary AST"
        
        $ "repr" `ast` `output` ["min"]:
          ? "Compiles from binary AST to CSS"

        --- "Documentation"
        $ "doc" `style` ["html", "md", "json"]:
          ? "Builds a documentation website"

  else:
    # Bro as a Nimble library
    import bropkg/engine/[parser, compiler]
    export parser, compiler