# A super fast stylesheet language for cool kids
#
# (c) 2023 George Lemon | LGPL License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

# Package

version       = "0.1.2"
author        = "George Lemon"
description   = "A super fast stylesheet language for cool kids!"
license       = "LGPL"
srcDir        = "src"
bin           = @["bro"]
binDir        = "bin"
installExt    = @["nim"]
skipDirs      = @["bro/utils"]

# Dependencies

requires "nim >= 2.0.0"
requires "checksums"
requires "toktok >= 0.1.2"
requires "kapsis"
requires "malebolgia"
requires "watchout#head"
requires "https://github.com/georgelemon/jsony#add-critbits-support" # jsony
requires "nyml#head"
requires "denim >= 0.1.7"
requires "chroma#head"
requires "stashtable >= 1.2.2"
requires "httpx", "websocketx"
requires "flatty", "supersnappy"

task dev, "development build":
  exec "nimble build --threads:on -d:useMalloc --mm:arc --deepcopy:on"

# task dll, "dynamic library build":
  # exec "nim c -f -d:release --app:lib --tlsEmulation:off --opt:speed --mm:arc -d:danger --noMain --out:./bin/libbro.so src/bro.nim"

task napi, "build for NodeJS":
  exec "denim build src/bro.nim --cmake --yes"

task propsgen, "Generate CSS Properties":
  # ignore undeclared identifier: 'Properties'
  exec "nim c --hints:off src/bropkg/utils/propsgen.nim"

task gen, "Generate dummy BASS files":
  exec "nim c -r tests/generators/functions.nim"

task wasm, "Compile to .wasm via Emscripten":
  exec "nim c -d:wasm src/bro.nim"

task bindings, "Generate bindings":
  exec "nim c --app:lib -d:bindings src/bro.nim"

task css, "Build CSS parser":
  exec "nim c --mm:arc --out:./bin/css src/bropkg/engine/css.nim"

task prod, "production build":
  exec "nimble build -d:release"