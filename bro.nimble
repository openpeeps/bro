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

requires "kapsis >= 0.3.4"
requires "openparser >= 0.1.2"
requires "flatty >= 0.4.0"
requires "checksums >= 0.2.2"
requires "semver >= 1.2.3"
# requires "denim >= 0.1.0"
requires "voodoo >= 0.1.9"
requires "vancode >= 0.1.1"
requires "chroma >= 0.1.0"
requires "watchout >= 0.2.2"