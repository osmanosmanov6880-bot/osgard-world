#!/usr/bin/env bash
# Godot may exit 0 after GDScript syntax errors: release guard must fail closed.
set -euo pipefail
check_log() {
  local logfile="$1"
  if [ ! -s "$logfile" ]; then
    echo 'R42 FAILURE: empty Godot import log' >&2
    return 1
  fi
  if grep -nE 'SCRIPT ERROR:|Parse Error:|Failed to load script' "$logfile"; then
    echo 'R42 FAILURE: Godot script parse/loading error occurred' >&2
    return 1
  fi
  if ! grep -q 'Godot Engine' "$logfile"; then
    echo 'R42 FAILURE: missing authentic Godot version banner' >&2
    return 1
  fi
  echo 'R42 PASS: real Godot imported with no script errors'
}
if [ "$#" -ge 1 ] && [ "$1" = '--validate-log' ]; then
  if [ "$#" -ne 2 ]; then echo 'Usage: --validate-log path' >&2; exit 2; fi
  check_log "$2"
  exit $?
fi
project="godot/empire-omega"
if [ "$#" -gt 0 ]; then project="$1"; fi
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
set +e
godot --headless --editor --path "$project" --import --quit >"$log" 2>&1
status=$?
set -e
cat "$log"
if [ "$status" -ne 0 ]; then
  echo "R42 FAILURE: Godot importer exited $status" >&2
  exit "$status"
fi
check_log "$log"
