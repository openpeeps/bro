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
    defaultCommand: "c"
    commands:
      c path(bass), ?filename("-o"), ?bool("-w"), ?bool("--sourceMap"), ?bool("--pretty"):
        ## Compile BASS to CSS with optional source map
      ast path(bass), ?filename("-o"):
        ## Generate binary AST from BASS/CSS
