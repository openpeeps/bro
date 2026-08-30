# Package

version       = "0.1.1"
author        = "George Lemon"
description   = "A super fast CSS preprocessor for cool kids!"
license       = "LGPL-3.0-or-later"
srcDir        = "src"
installExt    = @["nim"]
installDirs   = @["bro"]
bin           = @["bro"]
binDir        = "bin"


# Dependencies

requires "nim >= 2.0.0"

requires "kapsis >= 0.4.5"
requires "semver >= 1.2.3"
requires "openparser >= 0.2.0"
requires "checksums >= 0.2.2"
requires "voodoo >= 0.2.0"
requires "vancode >= 0.2.7"
requires "chroma >= 0.1.0"
requires "watchout >= 0.3.0"
