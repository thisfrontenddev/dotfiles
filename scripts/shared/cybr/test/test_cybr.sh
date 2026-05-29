#!/usr/bin/env bash
# Shell-assertion test harness for cybr. Run: bash scripts/shared/cybr/test/test_cybr.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0

assert_eq() { # desc, expected, actual
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s\n    expected: %q\n    actual:   %q\n' "$1" "$2" "$3"; fi
}
assert_contains() { # desc, haystack, needle
  if [[ "$2" == *"$3"* ]]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s\n    %q does not contain %q\n' "$1" "$2" "$3"; fi
}
assert_file() { # desc, path
  if [[ -e "$2" ]]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s\n    missing: %s\n' "$1" "$2"; fi
}

# --- Task 1 tests ---
echo "== Task 1: skeleton =="
out="$(bash "$HERE/cybr" 2>&1)"; rc=$?
assert_eq "no-args exits non-zero" "1" "$rc"
assert_contains "no-args prints usage" "$out" "Usage: cybr"

echo ""
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
