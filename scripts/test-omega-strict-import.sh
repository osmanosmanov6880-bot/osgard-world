#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
printf 'Godot Engine v4.4.1.stable.official\nImported files.\n' > "$temp/good.log"
bash "$root/omega-strict-godot-import.sh" --validate-log "$temp/good.log" >/dev/null
for bad in 'SCRIPT ERROR: wrong method' 'Parse Error: no such argument' 'ERROR: Failed to load script "res://main.gd"'; do
  printf 'Godot Engine v4.4.1.stable.official\n%s\n' "$bad" > "$temp/bad.log"
  if bash "$root/omega-strict-godot-import.sh" --validate-log "$temp/bad.log" >/dev/null 2>&1; then
    echo "FAIL: importer accepted $bad" >&2
    exit 1
  fi
done
: > "$temp/empty.log"
if bash "$root/omega-strict-godot-import.sh" --validate-log "$temp/empty.log" >/dev/null 2>&1; then
  echo 'FAIL: importer accepted empty log' >&2
  exit 1
fi
printf 'R42 strict import guard tests: 5/5 passed\n'
