# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "A super fast statically typed stylesheet language for cool kids"
license       = "MIT"
srcDir        = "src"
bin           = @["bro"]
binDir        = "bin"
installExt    = @["nim"]
skipDirs      = @["bro/utils"]

# Dependencies

requires "nim >= 1.6.10"
requires "toktok"
requires "kapsis"
requires "watchout"
requires "jsony"
requires "msgpack4nim"
requires "https://github.com/openpeeps/denim/"
requires "chroma#head"
requires "zippy"

task dev, "development build":
  exec "nimble build --threads:on -d:useMalloc --gc:arc --deepcopy:on"

# task dll, "dynamic library build":
  # exec "nim c -f -d:release --app:lib --tlsEmulation:off --opt:speed --gc:arc -d:danger --noMain --out:./bin/libbro.so src/bro.nim"

task node, "build for NodeJS":
  exec "denim build src/bro.nim"

task propsgen, "Generate CSS Properties":
  # ignore undeclared identifier: 'Properties'
  exec "nim c --hints:off src/utils/propsgen.nim"

task prod, "production build":
  exec "nimble build -d:release"