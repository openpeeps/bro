# Bootstrap macro benchmark — bro only, no zaiku
#
# Measures the full bro pipeline on bin/bootstrap.css (280kB, ~12k lines):
#   load → parse → codegen/validate → VM emit (minified) → sourcemap
# Optionally measures pretty + sourcemap variants.
#
# Usage:
#   nim c -d:release -o:bin/bench_bootstrap benchmarks/bench_bootstrap.nim
#   bin/bench_bootstrap                          # 1 run with breakdown
#   bin/bench_bootstrap --iterations 20          # median over N runs
#   bin/bench_bootstrap --warmup 3 --iterations 20
#   bin/bench_bootstrap --pretty                 # also bench pretty mode
#   bin/bench_bootstrap --help
#
# (c) 2026 George Lemon | LGPL License

import std/[os, monotimes, strutils, options, sequtils, algorithm, times, tables]

import ../src/bro/engine/vancodegen
import ../src/bro/engine/parser
import ../src/bro/engine/sourcemap
import pkg/vancode/interpreter/[ast, codegen, chunk, sym, vm, value]
import pkg/openparser/json

import ../src/bro/engine/stdlib/[libsystem, libarrays, libcolors]

const defaultBootstrapPath = "bin/bootstrap.css"

type PhaseTimes = object
  loadMs*: float
  parseMs*: float
  codegenMs*: float
  vmMs*: float
  mapMs*: float
  totalMs*: float
  pretty*: bool
  withMap*: bool
  cssLen*: int
  mapLen*: int

proc compileWithTimings(code, path: string, pretty, withMap: bool): (string, string, PhaseTimes) =
  ## Run one full compile and return (css, mapJson, timings). Separate
  ## phases are timed individually via getMonoTime.
  var tm: PhaseTimes
  tm.pretty = pretty
  tm.withMap = withMap

  # parse
  let tParse0 = getMonoTime()
  var program: Ast
  parser.parseScript(program, code, path)
  let tParse1 = getMonoTime()
  tm.parseMs = (tParse1 - tParse0).inMicroseconds.float / 1000.0

  # codegen + validate
  let tGen0 = getMonoTime()
  let mainChunk = newChunk(path)
  var script = newScript(mainChunk)
  var module = newModule(path.extractFilename, some(path))
  let systemModule = libsystem.loadLibrary(script, newJObject(), newJObject())
  module.load(systemModule)
  let colorsModule = libcolors.initColors(script, systemModule)
  module.load(colorsModule)
  let arraysModule = libarrays.initArrays(script, systemModule)
  module.load(arraysModule)
  script.stdpos = script.procs.high
  var gen = initCodeGen(script, module, mainChunk, parserCallback = nil)
  gen.genScript(program, none(string))
  let tGen1 = getMonoTime()
  tm.codegenMs = (tGen1 - tGen0).inMicroseconds.float / 1000.0

  # vm emit
  let tVm0 = getMonoTime()
  let virtualMachine = newVirtualMachine(VMPreferences(
    enableHotCodeDetection: true,
    hotProcThreshold: 10,
    hotChunkThreshold: 100
  ))
  if pretty:
    virtualMachine.globals["__bro_pretty"] = initValue(true)
  let css = virtualMachine.interpret(script, mainChunk).stringVal[]
  let tVm1 = getMonoTime()
  tm.vmMs = (tVm1 - tVm0).inMicroseconds.float / 1000.0
  tm.cssLen = css.len

  # sourcemap (build only, no file write)
  var mapJson = ""
  if withMap:
    let tMap0 = getMonoTime()
    var info = initSourceInfo()
    info.addContent(path, code)
    let segs = virtualMachine.globals.getOrDefault("__bro_sourcemap_segments").stringVal[]
    for record in segs.split('\x02'):
      if record.len == 0: continue
      let parts = record.split('\x03')
      if parts.len >= 4:
        let genCol = parseInt(parts[0])
        let line = parseInt(parts[1]) - 1
        let col = parseInt(parts[2])
        let segFile = parts[3]
        info.addSegment(0, genCol, segFile, line, col)
        if segFile notin info.contents:
          try: info.addContent(segFile, readFile(segFile))
          except CatchableError: discard
    let sm = info.toSourceMap(path.extractFilename.changeFileExt(".css"))
    let mapNode = newJObject()
    mapNode["version"] = newJInt(sm.version)
    mapNode["file"] = newJString(sm.file)
    let sources = newJArray()
    for s in sm.sources: sources.add(newJString(s))
    mapNode["sources"] = sources
    let contents = newJArray()
    for c in sm.sourcesContent: contents.add(newJString(c))
    mapNode["sourcesContent"] = contents
    mapNode["names"] = newJArray()
    mapNode["mappings"] = newJString(sm.mappings)
    mapJson = toJson(mapNode)
    let tMap1 = getMonoTime()
    tm.mapMs = (tMap1 - tMap0).inMicroseconds.float / 1000.0
    tm.mapLen = mapJson.len

  tm.totalMs = tm.parseMs + tm.codegenMs + tm.vmMs + tm.mapMs
  result = (css, mapJson, tm)

proc median(vals: seq[float]): float =
  if vals.len == 0: return 0
  var s = sorted(vals)
  let n = s.len
  if n mod 2 == 1: s[n div 2]
  else: (s[n div 2 - 1] + s[n div 2]) / 2.0

proc printHelp() =
  echo """Usage: bench_bootstrap [options]
  Benchmarks bro on bin/bootstrap.css (load→parse→validate→VM→sourcemap).

Options:
  --iterations N   measured runs (default 10, 1 = single breakdown)
  --warmup N       warmup runs excluded from stats (default 3)
  --pretty         also benchmark pretty mode (and pretty+map if --map)
  --map            also benchmark with sourcemap (minified+map)
  --path FILE      bootstrap path (default bin/bootstrap.css)
  --csv            emit CSV instead of markdown table
  --help           show this help
  --onlygen        only check that bootstrap parses (no timing, for hyperfine)
"""

when isMainModule:
  var iterations = 10
  var warmup = 3
  var doPretty = false
  var doMap = false
  var csv = false
  var path = defaultBootstrapPath
  var onlyGen = false

  var idx = 1
  while idx <= paramCount():
    let a = paramStr(idx)
    case a
    of "--help", "-h": printHelp(); quit(0)
    of "--pretty": doPretty = true
    of "--map": doMap = true
    of "--csv": csv = true
    of "--onlygen": onlyGen = true
    else:
      if a.startsWith("--iterations="): iterations = a.split('=')[1].parseInt
      elif a.startsWith("--warmup="): warmup = a.split('=')[1].parseInt
      elif a.startsWith("--path="): path = a.split('=')[1]
      elif a == "--iterations" and idx+1 <= paramCount():
        iterations = paramStr(idx+1).parseInt; inc idx
      elif a == "--warmup" and idx+1 <= paramCount():
        warmup = paramStr(idx+1).parseInt; inc idx
      elif a == "--path" and idx+1 <= paramCount():
        path = paramStr(idx+1); inc idx
      elif a == "--onlygen": onlyGen = true
    inc idx

  # silence validator warnings unless debugging
  codegen.warnHandler = proc(msg: string) {.gcsafe.} = discard

  if not fileExists(path):
    # fallback: try relative to repo root when invoked from different cwd
    let alt = "bin/bootstrap.css"
    if fileExists(alt): path = alt
    else:
      stderr.writeLine("bootstrap.css not found at " & path)
      quit(1)

  # --onlygen fast-path for hyperfine: just verify parse+emit once
  if onlyGen:
    let code = readFile(path)
    let (_, _, tm) = compileWithTimings(code, path, pretty=false, withMap=false)
    echo "ok css=" & $tm.cssLen
    quit(0)

  let code = readFile(path)
  let tLoad0 = getMonoTime()
  discard readFile(path)
  let loadMs = (getMonoTime() - tLoad0).inMicroseconds.float / 1000.0
  let inputSize = code.len
  let inputLines = code.count('\n') + 1

  echo "Bootstrap macro benchmark — bro only"
  echo "input : " & path & " (" & formatSize(inputSize) & ", " & $inputLines & " lines, " & $code.count('{') & " rules)"
  echo "load  : " & $loadMs & " ms (single readFile)"
  echo ""

  # Build matrix of modes to bench
  type BenchMode = tuple[pretty: bool, withMap: bool, label: string]
  var modes: seq[BenchMode] = @[(false, false, "minified")]
  if doMap: modes.add((false, true, "minified+map"))
  if doPretty: modes.add((true, false, "pretty"))
  if doPretty and doMap: modes.add((true, true, "pretty+map"))

  for mode in modes:
    # warmup
    for _ in 0 ..< warmup:
      discard compileWithTimings(code, path, mode.pretty, mode.withMap)

    var allParse, allGen, allVm, allMap, allTotal: seq[float]
    var cssLen, mapLen: int
    for _ in 0 ..< iterations:
      let (_, _, tm) = compileWithTimings(code, path, mode.pretty, mode.withMap)
      allParse.add(tm.parseMs)
      allGen.add(tm.codegenMs)
      allVm.add(tm.vmMs)
      allMap.add(tm.mapMs)
      allTotal.add(tm.totalMs)
      cssLen = tm.cssLen
      mapLen = tm.mapLen

    let medParse = median(allParse)
    let medGen = median(allGen)
    let medVm = median(allVm)
    let medMap = median(allMap)
    let medTotal = median(allTotal)
    let pCodegenPct = if medTotal > 0: medGen / medTotal * 100 else: 0
    let pVmPct = if medTotal > 0: medVm / medTotal * 100 else: 0

    if csv:
      echo "mode,iterations,warmup,parse_ms,codegen_ms,vm_ms,map_ms,total_ms,css_bytes,map_bytes"
      echo mode.label & "," & $iterations & "," & $warmup & "," &
        $medParse & "," & $medGen & "," & $medVm & "," & $medMap & "," &
        $medTotal & "," & $cssLen & "," & $mapLen
    else:
      echo "Mode: " & mode.label & "  (" & $iterations & " runs, " & $warmup & " warmup, median)"
      echo "| phase   | ms (median) | % of total |"
      echo "|---------|-------------|------------|"
      echo "| parse   | " & formatFloat(medParse, ffDecimal, 3) & " | " & formatFloat(medParse/medTotal*100, ffDecimal, 1) & "% |"
      echo "| codegen | " & formatFloat(medGen, ffDecimal, 3) & " | " & formatFloat(pCodegenPct, ffDecimal, 1) & "% |"
      echo "| vm emit | " & formatFloat(medVm, ffDecimal, 3) & " | " & formatFloat(pVmPct, ffDecimal, 1) & "% |"
      if mode.withMap:
        echo "| map     | " & formatFloat(medMap, ffDecimal, 3) & " | " & formatFloat(medMap/medTotal*100, ffDecimal, 1) & "% |"
      echo "| **total**| **" & formatFloat(medTotal, ffDecimal, 3) & "** | 100% |"
      echo "| output  | " & formatSize(cssLen) & " css" & (if mode.withMap: ", " & formatSize(mapLen) & " map" else: "") & " |  |"
      echo ""
      # also show min/max for total as sanity
      echo "  total range: " & formatFloat(min(allTotal), ffDecimal, 3) & " – " &
        formatFloat(max(allTotal), ffDecimal, 3) & " ms (median " &
        formatFloat(medTotal, ffDecimal, 3) & " ms, throughput " &
        formatFloat(inputSize.float / medTotal * 1000 / 1024, ffDecimal, 1) & " kB/s input)"
      echo ""
