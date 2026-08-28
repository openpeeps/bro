# Micro benchmarks — bro only, dummy small pieces
#
# Each case is a tiny BASS snippet exercising one engine path:
# nesting, &, mixins, control flow, imports not needed, raw calls, validation, selectors, at-rules.
# Runs N iterations per case with warmup, reports median µs and ops/sec.
#
# Usage:
#   nim c -d:release -o:bin/bench_micro benchmarks/bench_micro.nim
#   bin/bench_micro                          # all cases, 5000 iter
#   bin/bench_micro --iterations 10000 --warmup 100
#   bin/bench_micro --filter nesting         # substring match on case name
#   bin/bench_micro --list                   # list case names
#   bin/bench_micro --csv                    # CSV output
#
# (c) 2026 George Lemon | LGPL License

import std/[monotimes, strutils, options, sequtils, algorithm, os, times, tables]

import ../src/bro/engine/vancodegen
import ../src/bro/engine/parser
import pkg/vancode/interpreter/[ast, codegen, chunk, sym, vm, value]
import pkg/openparser/json

import ../src/bro/engine/stdlib/[libsystem, libarrays, libcolors]

type BenchCase = object
  name*: string
  code*: string
  hint*: string  # engine path it stresses

proc compile(code, path: string): string =
  var program: Ast
  parser.parseScript(program, code, path)
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
  var gen = initCodeGen(script, module, mainChunk)
  gen.genScript(program, none(string))
  let machine = newVirtualMachine(VMPreferences())
  result = machine.interpret(script, mainChunk).stringVal[]

proc median(vals: seq[float]): float =
  if vals.len == 0: return 0
  var s = sorted(vals)
  let n = s.len
  if n mod 2 == 1: s[n div 2]
  else: (s[n div 2 - 1] + s[n div 2]) / 2.0

let cases = @[
  BenchCase(name: "flat-10",
    hint: "normal path, no nesting",
    code: """
.a0 { color: red; padding: 0; }
.a1 { color: blue; margin: 1px; }
.a2 { color: green; border: 1px solid #000; }
.a3 { width: 100px; height: 50px; }
.a4 { font-size: 16px; line-height: 1.5; }
.a5 { background: #fff; }
.a6 { display: flex; }
.a7 { position: relative; top: 0; }
.a8 { opacity: 0.5; }
.a9 { z-index: 10; }
"""),
  BenchCase(name: "flat-100",
    hint: "normal path, 100 rules",
    code: block:
      var s = ""
      for i in 0 ..< 100: s &= ".a" & $i & " { color: #" & toHex(i*12345 mod 0xFFFFFF, 6) & "; padding: " & $i & "px; }\n"
      s
  ),
  BenchCase(name: "nesting-descendant",
    hint: "Sass nesting, descendant without &",
    code: """
.parent
  color: red
  .child
    color: blue
    .grand
      color: green
"""),
  BenchCase(name: "nesting-amp-hover",
    hint: "& replacement, pseudo",
    code: """
.card
  color: #333
  &:hover
    color: red
  &.active
    color: blue
  &::before
    content: ""
  & + .sib
    margin: 0
"""),
  BenchCase(name: "nesting-deep-amp",
    hint: "deep & at each level (vancodegen applyParent)",
    code: """
.a
  &:hover
    .b
      &.active
        color: red
        .c
          padding: 1rem
"""),
  BenchCase(name: "nesting-mixed-props",
    hint: "parent props + nested children + at-rule",
    code: """
.card
  padding: 1rem
  .title
    font-weight: bold
  @media (max-width: 768px)
    .body
      display: flex
  .footer
    color: #6c757d
"""),
  BenchCase(name: "mixin-basic",
    hint: "mixin def + expandMixin",
    code: """
mixin btn(color: color)
  color: $color
  border-radius: 4px
  padding: 0.5rem 1rem
.a
  @btn(red)
.b
  @btn(blue)
.c
  @btn(#0d6efd)
"""),
  BenchCase(name: "mixin-nested-selector",
    hint: "full splice: selectors inside mixin",
    code: """
mixin card
  .title
    font-weight: bold
  .body
    line-height: 1.5
.a
  color: red
  @card()
.b
  @card()
"""),
  BenchCase(name: "control-if",
    hint: "if/else inside rule (rawPropMode)",
    code: """
let $debug = true
.a
  color: red
  if $debug:
    outline: 1px solid blue
  else:
    outline: 0
  background: #fff
"""),
  BenchCase(name: "control-for-range",
    hint: "for range() with ${} unroll (parser)",
    code: """
.for-test
  for $i in range(1, 5):
    z-index: $i
"""),
  BenchCase(name: "control-for-array-inline",
    hint: "array-of-objects inline unroll",
    code: """
for $s in [{k: 0, v: 0}, {k: 1, v: 0.25rem}, {k: 2, v: 0.5rem}, {k: 3, v: 1rem}]:
  .m-${$s.k}
    margin: $s.v
"""),
  BenchCase(name: "control-for-array-var",
    hint: "var $arr + for $x in $arr",
    code: """
var $spacings = [{k: 0, v: 0}, {k: 1, v: 0.25rem}, {k: 2, v: 0.5rem}]
for $s in $spacings:
  .p-${$s.k}
    padding: $s.v
"""),
  BenchCase(name: "control-while",
    hint: "while + var mutation",
    code: """
var $i = 0
.a
  while $i < 3
    z-index: $i
    $i = $i + 1
"""),
  BenchCase(name: "control-case-of",
    hint: "case/of desugar → if chain",
    code: """
let $v = 2
.a
  case $v:
    of 1: color: red
    of 2: color: blue
    else: color: green
"""),
  BenchCase(name: "raw-call-linear-gradient",
    hint: "collectRawCall + nodeToCssString",
    code: """
.a
  background: linear-gradient(to right, red, blue)
.b
  background: linear-gradient(45deg, rgba(255,0,0,0.5) 25%, transparent 25%)
.c
  background: radial-gradient(circle at center, red, blue)
"""),
  BenchCase(name: "raw-call-many",
    hint: "many css functions (rgb, var, calc, clamp)",
    code: """
.a
  color: rgb(13 110 253 / 50%)
  background: var(--bs-body-bg)
  width: calc(100% - 2rem)
  height: clamp(1rem, 2.5vw, 2rem)
  grid: repeat(auto-fill, minmax(200px, 1fr))
  filter: drop-shadow(0 0 5px rgba(0,0,0,.5))
"""),
  BenchCase(name: "selectors-complex",
    hint: "attribute, pseudo, commas, combinators",
    code: """
[data-bs-theme=dark] .dropdown-menu { color: red; }
a[href^="http"], [data-x^="y"] { color: blue; }
.btn-check:checked+.btn { color: red; }
.table :is(thead,tbody,tfoot)>tr>th, td { padding: .5rem; }
.visually-hidden:not(caption) { position: absolute; }
"""),
  BenchCase(name: "at-rules",
    hint: "@media/@supports/@keyframes/@layer",
    code: """
@charset "utf-8";
@layer base, theme;
@media (min-width: 768px) { .a { color: red; } }
@supports (display: grid) { .b { display: grid; } }
@supports not (display: grid) { .c { display: flex; } }
@keyframes slide { from { opacity: 0 } to { opacity: 1 } }
@layer { .d { color: blue } }
"""),
  BenchCase(name: "properties-heavy",
    hint: "many declarations + validation (validate skip on large)",
    code: """
.heavy
  color: #0d6efd
  background: #fff
  border: 1px solid #dee2e6
  border-radius: 0.375rem
  box-shadow: 0 0.5rem 1rem rgba(0,0,0,0.15)
  padding: 0.75rem 1rem
  margin: 1rem 0
  font-size: 1rem
  line-height: 1.5
  display: flex
  position: relative
  z-index: 10
  opacity: 1
  width: 100%
  height: auto
"""),
  BenchCase(name: "values-comma-space",
    hint: "nkExprList + nkCommaList mixed",
    code: """
.x { margin: -0.375rem -0.75rem; }
.y { background-position: right 0.75rem center, center right 2.25rem; }
.z { box-shadow: 0 1px 2px rgba(0,0,0,.3), inset 0 0 0 1px red; }
.w { transition: all .3s ease-in-out; }
"""),
]

proc printHelp() =
  echo """Usage: bench_micro [options]
  Micro-benchmarks for isolated bro features (bro only).

Options:
  --iterations N   measured iterations per case (default 5000)
  --warmup N       warmup iterations per case (default 200)
  --filter SUB     only cases whose name contains SUB (case-insensitive)
  --list           list case names and hints, then exit
  --csv            CSV output
  --validate       also assert each case compiles to non-empty CSS (>0 bytes)
  --help           show this help
"""

when isMainModule:
  var iterations = 5000
  var warmup = 200
  var filter = ""
  var csv = false
  var doValidate = false
  var listOnly = false

  var idx = 1
  while idx <= paramCount():
    let a = paramStr(idx)
    case a
    of "--help", "-h": printHelp(); quit(0)
    of "--list": listOnly = true
    of "--csv": csv = true
    of "--validate": doValidate = true
    else:
      if a.startsWith("--iterations="): iterations = a.split('=')[1].parseInt
      elif a.startsWith("--warmup="): warmup = a.split('=')[1].parseInt
      elif a.startsWith("--filter="): filter = a.split('=')[1].toLowerAscii
      elif a == "--iterations" and idx+1 <= paramCount():
        iterations = paramStr(idx+1).parseInt; inc idx
      elif a == "--warmup" and idx+1 <= paramCount():
        warmup = paramStr(idx+1).parseInt; inc idx
      elif a == "--filter" and idx+1 <= paramCount():
        filter = paramStr(idx+1).toLowerAscii; inc idx
      elif not a.startsWith("--"): filter = a.toLowerAscii
    inc idx

  # silence validator warnings for clean bench output (warn-only path)
  codegen.warnHandler = proc(msg: string) {.gcsafe.} = discard

  if listOnly:
    for c in cases:
      echo c.name & "\t" & c.hint
    quit(0)

  let selected = cases.filterIt(filter.len == 0 or it.name.toLowerAscii.contains(filter))
  if selected.len == 0:
    stderr.writeLine("no cases match filter: " & filter)
    quit(1)

  if doValidate:
    for c in selected:
      let css = compile(c.code, "bench_" & c.name & ".bass")
      if css.len == 0:
        stderr.writeLine("validate fail: " & c.name & " produced empty CSS")
        quit(1)

  # warmup once across all selected to JIT/hot-code warm the VM
  for c in selected:
    for _ in 0 ..< min(warmup, 50):
      discard compile(c.code, "bench_" & c.name & ".bass")

  # header
  if csv:
    echo "case,hint,input_bytes,output_bytes,iterations,warmup,median_us,mean_us,min_us,max_us,ops_per_sec"
  else:
    echo "Micro benchmarks — bro only (" & $selected.len & " cases, " &
      $iterations & " iter, " & $warmup & " warmup)"
    echo ""
    echo "| case | median µs | ops/s | mean µs | min–max µs | in→out |"
    echo "|------|-----------|-------|---------|------------|--------|"

  for c in selected:
    # per-case warmup
    for _ in 0 ..< warmup:
      discard compile(c.code, "bench_" & c.name & ".bass")

    var samples: seq[float]
    samples.setLen(iterations)
    var cssLen: int
    for i in 0 ..< iterations:
      let t0 = getMonoTime()
      let css = compile(c.code, "bench_" & c.name & ".bass")
      let dt = (getMonoTime() - t0).inMicroseconds.float
      samples[i] = dt
      cssLen = css.len

    let med = median(samples)
    var sum = 0.0
    for v in samples: sum += v
    let mean = sum / samples.len.float
    let mn = min(samples)
    let mx = max(samples)
    let ops = if med > 0: 1_000_000.0 / med else: 0.0

    if csv:
      echo c.name & "," & "\"" & c.hint & "\"" & "," & $c.code.len & "," & $cssLen & "," &
        $iterations & "," & $warmup & "," &
        formatFloat(med, ffDecimal, 2) & "," &
        formatFloat(mean, ffDecimal, 2) & "," &
        formatFloat(mn, ffDecimal, 2) & "," &
        formatFloat(mx, ffDecimal, 2) & "," &
        formatFloat(ops, ffDecimal, 1)
    else:
      echo "| " & c.name & " | " & formatFloat(med, ffDecimal, 2) & " | " &
        formatFloat(ops, ffDecimal, 1) & " | " &
        formatFloat(mean, ffDecimal, 2) & " | " &
        formatFloat(mn, ffDecimal, 2) & "–" & formatFloat(mx, ffDecimal, 2) & " | " &
        formatSize(c.code.len) & "→" & formatSize(cssLen) & " |"

  if not csv:
    echo ""
    echo "Hint: " & selected.mapIt(it.hint).join(" | ")
    echo "Run with --filter <sub> to isolate a case, --csv for machine-readable."
