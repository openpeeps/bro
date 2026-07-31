#!/usr/bin/env bash
#
# Benchmark Bro's CSS compilation speed with hyperfine.
#
# Usage:
#   benchmarks/bench.sh [--count N] [--warmup N] [--runs N]
#
# Requires: hyperfine, a Nim toolchain, and bro's deps (uses `nimble build`).
#
set -euo pipefail

cd "$(dirname "$0")/.."

COUNT="${COUNT:-2000}"
WARMUP="${WARMUP:-3}"
RUNS="${RUNS:-5}"

echo "==> building bro (release)"
nimble build -d:release >/dev/null

echo "==> generating bench.bass with ~$COUNT components"
mkdir -p tests/data
nimble c -d:release --hints:off -o:bin/benchmark benchmarks/benchmark.nim 2>/dev/null || nimble c -d:release --hints:off benchmarks/benchmark.nim >/dev/null
./bin/benchmark --count "$COUNT" >/dev/null 2>&1 || true
# ensure a bench file exists (fall back to the packaged sample if generation failed)
if [ ! -f tests/stylesheets/bench.bass ]; then
  echo "  (using bin/style.bass as fallback)" >&2
  cp bin/style.bass tests/stylesheets/bench.bass
fi

echo "==> input size: $(du -h tests/data/bench.bass | cut -f1)"
echo

hyperfine \
  --warmup "$WARMUP" \
  --runs "$RUNS" \
  --export-markdown bin/bench-results.md \
  --command-name "bro compile (release)" \
  -- "cd \"$PWD\" && ./bin/bro compile ./tests/data/bench.bass"

echo
echo "results written to bin/bench-results.md"
