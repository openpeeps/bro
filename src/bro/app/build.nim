# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[os, monotimes, times, strutils, json, options, ropes]

import pkg/[flatty, jsony]
import pkg/kapsis/[cli, runtime]

import ../engine/parser
import ../engine/stdlib/[libsystem, libarrays, libcss]

import pkg/voodoo/language/[ast, codegen, chunk, sym, vm]
import pkg/voodoo/packagemanager/packager

proc parserCallback(astProgram: var Ast, path: string) =
  parser.parseScript(astProgram, readFile(path), path)

proc compileCode*(script: Script, module: Module, filename, code: string) =
  ## Compile some hayago code to the given script and module.
  ## Any generated toplevel code is discarded. This should only be used for
  ## declarations of hayago-side things, eg. iterators.
  var astProgram: Ast
  try:
    parser.parseScript(astProgram, code, "std/system/inline")
  except ParserError as e:
    echo e.msg
    quit(1)
  try:
    # var codeChunk = newChunk()
    var gen = initCodeGen(script, module, script.mainChunk)
    gen.genScript(astProgram, none(string), emitHalt = false)
  except CodeGenError as e:
    echo e.msg
    quit(1)

proc cssCommand*(v: Values) =
  ## Build CSS from Bro files
  var
    srcPath = $(v.get("in").getPath)
    outputPath = if v.has("-o"): v.get("-o").getStr else: ""

  if not srcPath.isAbsolute:
    srcPath = getCurrentDir() / srcPath

  # init the package manager and load the local packages
  let pkgr = packager.initPackageRemote()
  pkgr.loadPackages()

  let
    code = readFile(srcPath)
    t = getMonotime()
    data =
      if v.has("--data"):
        v.get("--data").getJson
      else:
        newJObject()
    globalData =
      if data != nil:
        if data.hasKey"app":
          data["app"]
        else: newJObject()
      else: newJObject()
    localData =
      if data != nil:
        if data.hasKey"this":
          data["this"]
        else: newJObject()
      else: newJObject()

  var program: Ast # the AST representation of the script
  try:
    parser.parseScript(program, code, srcPath)
  except ParserError as e:
    echo e.msg
    quit(1)

  var
    mainChunk = newChunk(srcPath)
    script = newScript(mainChunk)
    module = newModule(srcPath.extractFilename, some(srcPath))

  # load standard library modules
  let systemModule = libsystem.loadLibrary(script, globalData, localData)
  # module.load(systemModule)
  # let systemModule = newModule("system", some"system.timl")
  # systemModule.initSystemTypes()
  # script.compileCode(systemModule, "std/system", "")
  module.load(systemModule)

  let cssLib = initCSS(script, systemModule)
  module.load(cssLib)

  script.stdpos = script.procs.high


  try:
    # initalize the code generator and generate code for the script
    var compiler =
      codegen.initCodeGen(script, module, mainChunk, pkgr = pkgr,
                            parserCallback = parserCallback)
    compiler.genScript(program, none(string))
    
    # initialize a Voodoo VM and execute the script
    let vmInstance = newVm()
    let output = vmInstance.interpret(script, mainChunk)
    
    # Bro transpiles to CSS, so we expect the output to be a string of CSS code
    stdout.write output

  except CodeGenError as e:
    echo e.msg
    quit(1)

  # display the time taken for compilation
  # if flagBencmarks:
  #   displayInfo("Done in " & $(getMonotime() - t))