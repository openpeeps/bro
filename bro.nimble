# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "A super fast stylesheet language for cool kids!"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["bro"]
binDir        = "bin"


# Dependencies

requires "nim >= 2.0.0"

requires "kapsis#head"
requires "openparser"
requires "flatty"
requires "checksums"

requires "nyml#head"
requires "semver"
requires "dotenv"

requires "denim#head"
requires "voodoo"
requires "vancode"

requires "chroma"
requires "watchout#head"