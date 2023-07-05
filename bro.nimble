# Package

version       = "0.1.1"
author        = "George Lemon"
description   = "A super fast stylesheet language for cool kids!"
license       = "MIT"
srcDir        = "src"
bin           = @["bro"]
binDir        = "bin"
installExt    = @["nim"]
skipDirs      = @["bro/utils"]

# Dependencies

requires "nim >= 1.6.10"
requires "toktok#head"
requires "kapsis"
requires "watchout"
requires "jsony", "nyml"
requires "denim"
requires "chroma#head"
requires "zippy"
requires "pkginfo"
requires "stashtable"
requires "httpx", "websocketx"
requires "genny"

task dev, "development build":
  exec "nimble build --threads:on -d:useMalloc --gc:arc --deepcopy:on"

# task dll, "dynamic library build":
  # exec "nim c -f -d:release --app:lib --tlsEmulation:off --opt:speed --gc:arc -d:danger --noMain --out:./bin/libbro.so src/bro.nim"

task napi, "build for NodeJS":
  exec "denim build src/bro.nim --cmake --yes"

task propsgen, "Generate CSS Properties":
  # ignore undeclared identifier: 'Properties'
  exec "nim c --hints:off src/bropkg/utils/propsgen.nim"

task wasm, "Compile to .wasm via Emscripten":
  exec "nim c -d:wasm src/bro.nim"

task bindings, "Generate bindings":
  exec "nim c --app:lib -d:bindings src/bro.nim"

task prod, "production build":
  exec "nimble build -d:release"