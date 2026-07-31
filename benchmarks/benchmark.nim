# Bro benchmark generator + in-process timing harness.
#
# Generates a large, representative BASS stylesheet and, when compiled as a
# standalone binary, times the full parse -> codegen -> VM pipeline.
#
# Usage:
#   nim c -d:release -o:bin/benchmark benchmarks/benchmark.nim
#   bin/benchmark            # print timing + write bin/bench.bass
#   bin/benchmark --onlygen  # only write the .bass file (for hyperfine)
#
# (c) 2026 George Lemon | LGPL License

import std/[os, monotimes, options, strutils, times]

import ../src/bro/engine/vancodegen
import ../src/bro/engine/parser
import pkg/vancode/interpreter/[ast, codegen, chunk, sym, vm, value]
import pkg/openparser/json

import ../src/bro/engine/stdlib/libsystem

proc generate(count: int): string =
  ## Build a synthetic stylesheet with `count` component blocks.
  var buf: string
  # CSS custom properties on :root
  buf.add ":root {\n"
  for i in 0 ..< 40:
    buf.add "  --bs-color-" & $i & ": #0d6efd;\n"
  buf.add "}\n\n"

  # utility classes
  for i in 0 ..< count:
    buf.add ".p-" & $i & " { padding: " & $i & "rem; }\n"
    buf.add ".m-" & $i & " { margin: " & $i & "rem; }\n"
    buf.add ".fs-" & $i & " { font-size: " & $(0.5 + i.float / 10) & "rem; }\n"

  # component blocks with nested selectors
  for i in 0 ..< count:
    buf.add ".component-" & $i & " {\n"
    buf.add "  color: #333;\n"
    buf.add "  background-color: var(--bs-color-" & $(i mod 40) & ");\n"
    buf.add "  border: 1px solid #ccc;\n"
    buf.add "  .title {\n"
    buf.add "    font-size: " & $(1 + (i mod 3)) & ".25rem;\n"
    buf.add "    font-weight: bold;\n"
    buf.add "  }\n"
    buf.add "  .body {\n"
    buf.add "    line-height: 1.5;\n"
    buf.add "    padding: 1rem;\n"
    buf.add "    margin: -0.5rem -0.25rem;\n"
    buf.add "  }\n"
    buf.add "}\n\n"

  # media queries
  for i in 0 ..< (count div 2):
    buf.add "@media (min-width: " & $(576 + i * 10) & "px) {\n"
    buf.add "  .component-" & $i & " .title { font-size: 2rem; }\n"
    buf.add "  .component-" & $i & " .body { display: flex; }\n"
    buf.add "}\n\n"

  # keyframes
  for i in 0 ..< (count div 2):
    buf.add "@keyframes slide-" & $i & " {\n"
    buf.add "  from { opacity: 0; transform: translateY(-10px); }\n"
    buf.add "  to { opacity: 1; transform: translateY(0); }\n"
    buf.add "}\n\n"
  result = buf

proc compileInProcess(code, path: string): (string, float) =
  ## Parse + codegen + VM the given source, returning (css, seconds).
  let t0 = getMonoTime()
  var program: Ast
  parser.parseScript(program, code, path)
  let t1 = getMonoTime()

  let mainChunk = newChunk(path)
  var script = newScript(mainChunk)
  var module = newModule(path.extractFilename, some(path))
  let systemModule = libsystem.loadLibrary(script, newJObject(), newJObject())
  module.load(systemModule)
  script.stdpos = script.procs.high

  var gen = initCodeGen(script, module, mainChunk)
  gen.genScript(program, none(string))
  let t2 = getMonoTime()

  let virtualMachine = newVirtualMachine(VMPreferences())
  let css = virtualMachine.interpret(script, mainChunk).stringVal[]
  let t3 = getMonoTime()

  let ms = (t3 - t0).inMilliseconds.float
  result = (css, ms)

when isMainModule:
  let count =
    if paramCount() > 0 and paramStr(1) == "--count":
      if paramCount() > 1: paramStr(2).parseInt else: 2000
    else: 2000

  let outPath = "tests/data/bench.bass"
  let cssPath = "tests/data/bench.css"
  createDir("tests/data")
  let code = generate(count)
  writeFile(outPath, code)

  let (css, ms) = compileInProcess(code, outPath)
  writeFile(cssPath, css)

  let selectors = count * 6 + count * 4 + count div 2 + count div 2
  echo "generated selectors: ~", selectors
  echo "input : ", outPath, " (", formatSize(code.len), ")"
  echo "output: ", cssPath, " (", formatSize(css.len), ")"
  echo "total : ", ms, " ms"
