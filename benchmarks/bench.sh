#!/usr/bin/env bash
#
# Benchmark Bro — bro only (no zaiku)
#
# Two suites:
#   1) macro  — bin/bootstrap.css 280kB → parse/validate/minified + sourcemap
#   2) micro  — dummy small pieces covering nesting/&/mixins/loops/raw-calls etc.
#
# Also keeps the legacy synthetic scaling bench for throughput history.
#
# Usage:
#   benchmarks/bench.sh                      # all suites
#   benchmarks/bench.sh --macro-only         # only bootstrap macro
#   benchmarks/bench.sh --micro-only         # only micro
#   benchmarks/bench.sh --count N --warmup N --runs N   # synthetic opts
#   benchmarks/bench.sh --help
#
# Requires: Nim toolchain (nimble), optional: hyperfine for CLI timing.
#
set -euo pipefail

cd "$(dirname "$0")/.."

COUNT="${COUNT:-2000}"
WARMUP="${WARMUP:-3}"
RUNS="${RUNS:-5}"
BOOTSTRAP="bin/bootstrap.css"
DO_MACRO=1
DO_MICRO=1
DO_SYNTH=0
DO_HYPERFINE=0

for arg in "$@"; do
  case "$arg" in
    --macro-only) DO_MICRO=0; DO_SYNTH=0 ;;
    --micro-only) DO_MACRO=0; DO_SYNTH=0 ;;
    --synthetic) DO_SYNTH=1 ;;
    --synthetic-only) DO_MACRO=0; DO_MICRO=0; DO_SYNTH=1 ;;
    --hyperfine) DO_HYPERFINE=1 ;;
    --count=*) COUNT="${arg#*=}" ;;
    --warmup=*) WARMUP="${arg#*=}" ;;
    --runs=*) RUNS="${arg#*=}" ;;
    --help|-h)
      echo "Usage: benchmarks/bench.sh [options]"
      echo "  --macro-only     only bootstrap macro bench"
      echo "  --micro-only     only micro benches"
      echo "  --synthetic      also run synthetic scaling bench"
      echo "  --synthetic-only only synthetic bench"
      echo "  --hyperfine      also run hyperfine on bro CLI (if installed)"
      echo "  --count=N        synthetic component count (default $COUNT)"
      echo "  --warmup=N       hyperfine warmup (default $WARMUP)"
      echo "  --runs=N         hyperfine runs (default $RUNS)"
      exit 0
      ;;
  esac
done

echo "==> building bro + benches (release)"
nimble build -d:release >/dev/null 2>&1 || echo "  (nimble build warnings, continuing)"
# Use clue's local vancode/openparser paths (develop-linked) to match `clue build`
nim c --path:/Users/georgelemon/Development/packages/vancode/src --path:/Users/georgelemon/Development/packages/openparser/src -d:release --deepcopy:on --hints:off -o:bin/bench_bootstrap benchmarks/bench_bootstrap.nim 2>/dev/null || nim c --path:/Users/georgelemon/Development/packages/vancode/src --path:/Users/georgelemon/Development/packages/openparser/src -d:release --deepcopy:on -o:bin/bench_bootstrap benchmarks/bench_bootstrap.nim 2>&1 | tail -n 5
nim c --path:/Users/georgelemon/Development/packages/vancode/src --path:/Users/georgelemon/Development/packages/openparser/src -d:release --deepcopy:on --hints:off -o:bin/bench_micro benchmarks/bench_micro.nim 2>/dev/null || nim c --path:/Users/georgelemon/Development/packages/vancode/src --path:/Users/georgelemon/Development/packages/openparser/src -d:release --deepcopy:on -o:bin/bench_micro benchmarks/bench_micro.nim 2>&1 | tail -n 5

if [ "$DO_MACRO" = 1 ]; then
  echo ""
  echo "━━━ macro: $BOOTSTRAP (load→parse→validate→minified + sourcemap) ━━━"
  if [ ! -f "$BOOTSTRAP" ]; then
    echo "  skip: $BOOTSTRAP not found" >&2
  else
    # single breakdown
    ./bin/bench_bootstrap --iterations 1 --warmup 0
    echo "--- median over 10 runs (minified / minified+map / pretty) ---"
    ./bin/bench_bootstrap --iterations 10 --warmup 3
    ./bin/bench_bootstrap --iterations 10 --warmup 3 --map
    ./bin/bench_bootstrap --iterations 10 --warmup 3 --pretty --map
  fi
fi

if [ "$DO_MICRO" = 1 ]; then
  echo ""
  echo "━━━ micro: dummy small pieces (nesting, &, mixins, loops, etc.) ━━━"
  ./bin/bench_micro --iterations 500 --warmup 50
fi

if [ "$DO_SYNTH" = 1 ]; then
  echo ""
  echo "━━━ synthetic scaling (legacy) — ~$COUNT components ━━━"
  mkdir -p tests/data
  nim c --path:/Users/georgelemon/Development/packages/vancode/src --path:/Users/georgelemon/Development/packages/openparser/src -d:release --deepcopy:on --hints:off -o:bin/benchmark benchmarks/benchmark.nim 2>/dev/null || nim c --path:/Users/georgelemon/Development/packages/vancode/src --path:/Users/georgelemon/Development/packages/openparser/src -d:release --deepcopy:on --hints:off benchmarks/benchmark.nim >/dev/null
  ./bin/benchmark --count "$COUNT" >/dev/null 2>&1 || true
  if [ ! -f tests/data/bench.bass ]; then
    echo "  (using bin/style.bass as fallback)" >&2
    cp bin/style.bass tests/data/bench.bass 2>/dev/null || true
  fi
  if [ -f tests/data/bench.bass ]; then
    echo "  input: $(du -h tests/data/bench.bass | cut -f1) $(wc -l < tests/data/bench.bass) lines"
    ./bin/benchmark --count "$COUNT" 2>/dev/null | tail -n 5 || ./bin/benchmark 2>/dev/null | tail -n 5 || true
  fi
fi

if [ "$DO_HYPERFINE" = 1 ]; then
  if ! command -v hyperfine >/dev/null 2>&1; then
    echo "hyperfine not installed — skip CLI timing" >&2
  else
    echo ""
    echo "━━━ hyperfine: bro compile $BOOTSTRAP ━━━"
    mkdir -p bin
    hyperfine \
      --warmup "$WARMUP" \
      --runs "$RUNS" \
      --export-markdown bin/bench-results.md \
      --command-name "bro compile $BOOTSTRAP" \
      -- "cd \"$PWD\" && ./bin/bro compile ./$BOOTSTRAP -o /tmp/bro-bench.css 2>/dev/null || ./bin/bro compile ./$BOOTSTRAP 2>/dev/null | wc -c >/dev/null"
    echo "results written to bin/bench-results.md"
    cat bin/bench-results.md 2>/dev/null || true
  fi
fi

echo ""
echo "Done. Binaries: bin/bench_bootstrap, bin/bench_micro, bin/bro"
echo "  quick: bin/bench_bootstrap --iterations 20 --map --pretty"
echo "  quick: bin/bench_micro --filter nesting --iterations 5000"
