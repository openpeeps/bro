# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/tim
import ./bro/engine/vancodegen

when isMainModule:
  # Building Bro as a CLI application
  import pkg/kapsis
  import pkg/kapsis/[runtime, cli]
  import ./bro/app/build

  initKapsis do:
    defaultCommand: "compile"
    commands:
      compile path(bass), ?filename("-o"), ?bool("-w"), ?bool("--sourceMap"):
        ## Build CSS from BASS files
      ast path(bass), ?filename("-o"):
        ## Build AST from BASS files