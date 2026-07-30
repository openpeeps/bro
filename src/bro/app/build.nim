# A super fast stylesheet language for cool kids!
#
# (c) 2026 George Lemon | LGPL-v3 License
#          Made by Humans from OpenPeeps
#          https://github.com/openpeeps/bro

import std/[os, monotimes, times, options]

import pkg/watchout
import pkg/[openparser/json]
import pkg/kapsis/[cli, runtime, interactive/prompts]

import pkg/vancode/interpreter/[ast, codegen, chunk, sym, vm, value, resolver]
import pkg/vancode/manager/packager

import ../engine/parser
import ../engine/stdlib/[libsystem, libarrays, libcolors]

proc parserCallback(astProgram: var Ast, path: string, resolver: FileResolver) =
  parser.parseScript(astProgram, readFile(path), path)

proc compileCode(filePath: string,
          pkgr: Packager, globalData: JsonNode, localData: JsonNode,
          output: bool = false, outputPath: string = "") =
  # Compile the BASS code at `filePath` and optionally save the output to `
  var program: Ast # the AST representation of the script
  let code = readFile(filePath)
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
    if not output:
      echo(virtualMachine.interpret(script, mainChunk))
    else:
      let cssOutput = virtualMachine.interpret(script, mainChunk).stringVal[]
      let outputFilePath = outputPath.changeFileExt(".css")
      # if fileExists(outputFilePath):
      writeFile(outputFilePath, cssOutput)
  except CodeGenError as e:
    echo e.msg

var browserSyncWatcher: Watchout
proc compileCommand*(v: Values) =
  ## Kapsis command for compiling BASS files to CSS
  var srcPath = $(v.get("bass").getPath)
  
  var hasOutput: bool
  var outputPath =
    if v.has("-o"):
      hasOutput = true
      v.get("-o").getFilename
    else: ""

  let enabledWatch = v.has("-w")

  if not srcPath.isAbsolute:
    srcPath = getCurrentDir() / srcPath
  
  if hasOutput and outputPath.isAbsolute:
    outputPath = getCurrentDir() / outputPath

  # init the package manager and load the local packages
  let pkgr = packager.initPackageRemote()
  pkgr.loadPackages()

  let
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

  # compile the code for the first time
  compileCode(srcPath, pkgr, globalData, localData, hasOutput, outputPath)

  # initialize the file watcher for browser sync if watch mode is enabled
  if enabledWatch:
    if not hasOutput:
      displayInfo("Watching for file changes...")
    
    # Set up a file watcher to recompile on changes
    browserSyncWatcher = newWatchout(@[srcPath.parentDir], some("*.bass"))

    proc onChange(file: watchout.File) =
      if not hasOutput:
        # If no output file is specified, just recompile and print
        # the resulted CSS in the console
        compileCode(file.getPath, pkgr, globalData, localData, false, "")
      else:
        let t = cpuTime()
        compileCode(file.getPath, pkgr, globalData, localData, hasOutput, outputPath)
        displayInfo("File changed: " & file.getPath)
        displaySuccess("Recompiled in " & $((cpuTime() - t)) & "s")

    proc onDelete(file: watchout.File) = discard

    # Set up file watcher callbacks and start watching for changes
    browserSyncWatcher.onChange = onChange
    browserSyncWatcher.onDelete = onDelete
    browserSyncWatcher.start()

    while true:
      sleep(1000) # keep the program running to watch for file changes