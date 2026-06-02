# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[os, monotimes, times, strutils, options, ropes]

import pkg/watchout
import pkg/[flatty, openparser/json]
import pkg/kapsis/[cli, runtime, interactive/prompts]

import ../engine/parser
import ../engine/stdlib/[libsystem, libarrays, libcss]

import pkg/vancode/interpreter/[ast, codegen, chunk, sym, vm, value, resolver]
import pkg/vancode/manager/packager

proc parserCallback(astProgram: var Ast, path: string, resolver: FileResolver) =
  parser.parseScript(astProgram, readFile(path), path)

proc compileCode*(script: Script, module: Module, filename, code: string) =
  ## Compile some hayago code to the given script and module.
  ## Any generated toplevel code is discarded. This should only be used for
  ## declarations of hayago-side things, eg. iterators.
  var astProgram: Ast
  try:
    parser.parseScript(astProgram, code, "std/system/inline")
  except BroParserError as e:
    echo e.msg
    quit(1)
  try:
    # var codeChunk = newChunk()
    var gen = initCodeGen(script, module, script.mainChunk)
    gen.genScript(astProgram, none(string), emitHalt = false)
  except CodeGenError as e:
    echo e.msg
    quit(1)

var browserSyncWatcher: Watchout
proc compileCommand*(v: Values) =
  ## Kapsis command for compiling BASS files to CSS
  var srcPath = $(v.get("bass").getPath)
  
  let outputPath =
    if v.has("-o"): v.get("-o").getStr
    else: ""
  let enabledWatch = v.has("-w")

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

  proc compileCode(filePath: string) =
    var program: Ast # the AST representation of the script
    try:
      parser.parseScript(program, code, filePath)
    except BroParserError as e:
      echo e.msg
      quit(1)

    var mainChunk = newChunk(filePath)
    var script = newScript(mainChunk)
    var module = newModule(filePath.extractFilename, some(filePath))

    # load standard library modules
    let systemModule = libsystem.loadLibrary(script, globalData, localData)
    module.load(systemModule)

    let cssLib = initCSS(script, systemModule)
    module.load(cssLib)

    script.stdpos = script.procs.high

    # compile the code and handle any errors
    try:
      var compiler = initCodeGen(script, module, mainChunk,
                                   pkgr = pkgr, parserCallback = parserCallback)
      compiler.genScript(program, none(string))
      
      # initialize a Voodoo VM and execute the script
      let virtualMachine = newVirtualMachine(VMPreferences(
        enableHotCodeDetection: true,
        hotProcThreshold: 10,
        hotChunkThreshold: 100
      ))
      echo(virtualMachine.interpret(script, mainChunk))
    except CodeGenError as e:
      echo e.msg

  # compile the code for the first time
  compileCode(srcPath)

  # initialize the file watcher for browser sync if watch mode is enabled
  if enabledWatch:
    if outputPath.len != 0:
      displayInfo("Watching for file changes...")
    
    # Set up a file watcher to recompile on changes
    browserSyncWatcher = newWatchout(@[srcPath.parentDir], some("*.bass"))

    proc onChange(file: watchout.File) =
      if outputPath.len == 0:
        compileCode(file.getPath)
      else:
        let t = cpuTime()
        compileCode(file.getPath)
        displaySuccess("File changed: " & file.getPath)
        displayInfo("Recompiled in " & $((cpuTime() - t)) & "s")

    proc onDelete(file: watchout.File) = discard

    # Set up file watcher callbacks and start watching for changes
    browserSyncWatcher.onChange = onChange
    browserSyncWatcher.onDelete = onDelete
    browserSyncWatcher.start()

    while true:
      sleep(1000) # keep the program running to watch for file changes