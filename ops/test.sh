#!/usr/bin/env bash
# Runs the GUT suite. Godot exits 0 when a test script fails to parse (GUT just skips it), so this
# also fails on script errors and on any tests/**/test_*.gd missing from the run.
# With arguments, they replace the suite selection, e.g. ops/test.sh -gtest=res://tests/unit/test_unit.gd
set -uo pipefail
cd "$(dirname "$0")/.."
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

select=(-gdir=res://tests -ginclude_subdirs)
[ $# -gt 0 ] && select=("$@")
godot --headless --path . -s addons/gut/gut_cmdln.gd "${select[@]}" -gexit 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

fail=0
if [ $# -eq 0 ]; then
  # The map generator's own tests.
  if ! python3 -m unittest discover -s tests/tools 2>&1 | tail -4; then
    echo "ops/test.sh: the map generator's tests failed" >&2; fail=1
  fi
fi
if [ "$status" -ne 0 ]; then
  echo "ops/test.sh: godot exited $status" >&2; fail=1
fi
if grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script' "$log"; then
  echo "ops/test.sh: script errors in the output" >&2; fail=1
fi
if grep -qE '^Failing Tests +[1-9]' "$log"; then
  echo "ops/test.sh: failing tests" >&2; fail=1
fi
if ! grep -qE '^Passing Tests +[1-9]' "$log"; then
  echo "ops/test.sh: no passing tests reported" >&2; fail=1
fi
if [ $# -eq 0 ]; then
  expected=$(find tests -name 'test_*.gd' | wc -l | tr -d ' ')
  ran=$(sed -nE 's/^Scripts +([0-9]+).*/\1/p' "$log" | tail -1)
  if [ "${ran:-0}" != "$expected" ]; then
    echo "ops/test.sh: ran ${ran:-0} of $expected test scripts" >&2; fail=1
  fi
fi
exit $fail
