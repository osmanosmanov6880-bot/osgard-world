#!/usr/bin/env bash
# Run through SSH stdin before mkdir or SCP, no remote filesystem mutation.
set -euo pipefail
minimum_bytes="${1:-}"
case "$minimum_bytes" in
  ''|*[!0-9]*) echo 'Invalid native-game capacity requirement' >&2; exit 2;;
esac
if [ "$minimum_bytes" -le 0 ] || [ "$minimum_bytes" -gt 12884901888 ]; then
  echo 'Native-game capacity requirement outside safe bounds' >&2
  exit 2
fi
free_kib="$(LC_ALL=C df -Pk /tmp | awk 'NR==2 {print $4}')"
case "$free_kib" in
  ''|*[!0-9]*) echo 'Cannot establish verified VPS free disk space' >&2; exit 3;;
esac
available_bytes=$((free_kib * 1024))
if [ "$available_bytes" -lt "$minimum_bytes" ]; then
  echo "Insufficient remote disk before native Godot SCP: free ${available_bytes} B, required ${minimum_bytes} B" >&2
  exit 4
fi
echo "PASS: native Omega upload has ${available_bytes} B free, ${minimum_bytes} B reserved"
