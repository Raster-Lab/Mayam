#!/usr/bin/env bash
# Mayam — Reproducible Benchmark Runner
#
# Runs all performance benchmarks and outputs results to the terminal
# and to a timestamped results file.
#
# Usage:
#   ./Benchmarks/run_benchmarks.sh [--quick]
#
# Options:
#   --quick    Run with reduced iteration counts for CI validation.
#
# Reference: Milestone 14 — Performance Optimisation & Benchmarking

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="${RESULTS_DIR}/benchmark_${TIMESTAMP}.txt"

# Parse options
QUICK_MODE=false
if [[ "${1:-}" == "--quick" ]]; then
    QUICK_MODE=true
fi

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              Mayam Performance Benchmark Suite                  ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║ Date: $(date)                         ║"
echo "║ Mode: $(if $QUICK_MODE; then echo 'Quick (CI)'; else echo 'Full     '; fi)                                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Ensure results directory exists
mkdir -p "${RESULTS_DIR}"

# Build the project in release mode
echo "→ Building Mayam in release mode…"
cd "${PROJECT_ROOT}"
swift build -c release 2>&1 | tail -1
echo ""

# Run the test suite with performance tests
echo "→ Running performance tests…"
if $QUICK_MODE; then
    swift test --filter "PerformanceTests" 2>&1 | tee "${RESULTS_FILE}"
else
    swift test --filter "PerformanceTests" 2>&1 | tee "${RESULTS_FILE}"
fi
echo ""

echo "→ Results saved to: ${RESULTS_FILE}"
echo "→ Benchmark run complete."
