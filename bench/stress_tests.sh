#!/bin/bash
# Runs `bal test` repeatedly while the machine is busy, to find tests that only pass on a quiet one.
#
# usage: [LOAD=n] bench/stress_tests.sh <directory> <iterations> [bal test arguments...]
#   LOAD   busy processes to run alongside (default: twice the number of cores)
#
# Each run is reported as PASS, FAIL (a test failed), COMPILE-ERROR, or NO-TESTS-RAN. The last two matter:
# a package that does not compile prints no "[fail]" line, and treating "nothing failed" as a pass hides it.
# The exit status is 0 only when every run is PASS. Logs are kept in a temporary directory that is printed.
set -u
dir=${1:?usage: stress_tests.sh <directory> <iterations> [bal test arguments...]}
iterations=${2:?usage: stress_tests.sh <directory> <iterations> [bal test arguments...]}
shift 2
cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
load=${LOAD:-$((cores * 2))}
logs=$(mktemp -d "${TMPDIR:-/tmp}/stress-tests.XXXXXX")

pids=()
cleanup() { for p in "${pids[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done; }
trap cleanup EXIT INT TERM
i=0
while [ "$i" -lt "$load" ]; do
  yes > /dev/null &
  pids+=("$!")
  i=$((i + 1))
done

echo "$load busy processes on $cores cores; logs in $logs"
cd "$dir" || exit 2
bad=0
n=1
while [ "$n" -le "$iterations" ]; do
  log=$logs/run-$n.log
  start=$(date +%s)
  bal test "$@" > "$log" 2>&1
  seconds=$(( $(date +%s) - start ))
  total=$(grep -E '^[[:space:]]+[0-9]+ passing' "$log" | awk '{s += $1} END {print s + 0}')
  failing=$(grep -cE '^[[:space:]]+[1-9][0-9]* failing' "$log")
  failed=$(grep -E '^[[:space:]]*\[fail\]' "$log" | sed 's/^[[:space:]]*//' | sort -u | tr '\n' ';')
  verdict=PASS
  [ "$total" -eq 0 ] && verdict=NO-TESTS-RAN
  [ "$failing" -gt 0 ] && verdict=FAIL
  [ -n "$failed" ] && verdict=FAIL
  grep -qE '^ERROR|compilation contains errors' "$log" && verdict=COMPILE-ERROR
  [ "$verdict" != PASS ] && bad=$((bad + 1))
  echo "run $n: ${seconds}s, $total tests, $verdict ${failed:+- $failed}"
  n=$((n + 1))
done
echo "$((iterations - bad)) of $iterations runs passed"
[ "$bad" -eq 0 ]
