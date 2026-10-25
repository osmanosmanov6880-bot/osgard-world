#!/bin/sh
# Preserve only independently staged, SHA-verified NEBULA R40 QA during
# full-site frontend activation. Never touches production /arena-v2/nebula-3d.
set -eu
active="$1"
candidate="$2"
pin_file="$3"
case "$active:$candidate" in
  /*/games/remix/nebula-r40-qa:/*/html/games/remix/nebula-r40-qa) ;;
  *) echo 'Unsafe NEBULA QA path pair' >&2; exit 2 ;;
esac
[ "$active" != "$candidate" ] && [ ! -L "$active" ] && [ ! -L "$candidate" ] || {
  echo 'Refusing symlinked or identical NEBULA QA directories' >&2
  exit 2
}
[ -s "$pin_file" ] && [ ! -L "$pin_file" ] || {
  echo 'Missing or unsafe reviewed QA source head pin' >&2
  exit 2
}
pinned="$(cat "$pin_file")"
case "$pinned" in *[!0-9a-f]*|'') echo 'Invalid QA head SHA pin' >&2; exit 2 ;; esac
[ "$(printf '%s' "$pinned" | wc -c)" -eq 40 ] || {
  echo 'QA source SHA must be 40 hex characters' >&2
  exit 2
}
# A missing CI manifest means QA is not staged, NOT that a generic index
# page is an approved substitute. Leave this site release otherwise intact.
if [ ! -s "$active/R40_DEVICE_ARTIFACT_SHA256.txt" ]; then
  echo 'NEBULA_R40_QA_NOT_STAGED: no attested active candidate to preserve'
  exit 0
fi
for file in index.html index.js index.wasm index.pck \
  R40_DEVICE_ARTIFACT_SHA256.txt R40_DEVICE_ARTIFACT_PROVENANCE.txt; do
  [ -s "$active/$file" ] && [ ! -L "$active/$file" ] || {
    echo "Attested NEBULA QA missing or symlinked $file" >&2
    exit 1
  }
done
if find "$active" -type l | grep -q .; then
  echo 'Refusing attested NEBULA QA containing any symlink' >&2
  exit 1
fi
sums="$active/R40_DEVICE_ARTIFACT_SHA256.txt"
[ "$(wc -l < "$sums")" -eq 4 ] &&
[ "$(grep -Ec '^[a-f0-9]{64}  (index[.]html|index[.]js|index[.]wasm|index[.]pck)$' "$sums")" -eq 4 ] || {
  echo 'Unsafe or incomplete R40 candidate SHA-256 manifest' >&2
  exit 1
}
for name in index.html index.js index.wasm index.pck; do
  [ "$(awk -v name="$name" '$2==name {n++} END {print n+0}' "$sums")" -eq 1 ] || {
    echo "Missing or duplicated hash for $name" >&2
    exit 1
  }
done
grep -Fxq "pull_request_head_sha=$pinned" "$active/R40_DEVICE_ARTIFACT_PROVENANCE.txt" &&
grep -Fxq 'source_branch=release/nebula-r40-final-hardware-qa-20261025' "$active/R40_DEVICE_ARTIFACT_PROVENANCE.txt" &&
grep -Fxq 'release_status=HARDWARE_QA_ONLY_NOT_PRODUCTION' "$active/R40_DEVICE_ARTIFACT_PROVENANCE.txt" || {
  echo 'NEBULA QA provenance differs from reviewed original PR head' >&2
  exit 1
}
(cd "$active" && sha256sum -c R40_DEVICE_ARTIFACT_SHA256.txt >/dev/null) || {
  echo 'NEBULA QA bytes changed after isolated staging' >&2
  exit 1
}
stage="$candidate.verified.$$"
backup="$candidate.previous.$$"
[ ! -e "$stage" ] && [ ! -e "$backup" ] || exit 2
mkdir -p "$(dirname "$candidate")"
if ! cp -a "$active" "$stage"; then
  rm -rf "$stage"
  echo 'Cannot copy verified QA before frontend swap' >&2
  exit 1
fi
if ! (cd "$stage" && sha256sum -c R40_DEVICE_ARTIFACT_SHA256.txt >/dev/null); then
  rm -rf "$stage"
  echo 'Copied QA failed SHA-256 verification' >&2
  exit 1
fi
if [ -e "$candidate" ]; then mv "$candidate" "$backup"; fi
if ! mv "$stage" "$candidate"; then
  [ ! -d "$backup" ] || mv "$backup" "$candidate"
  rm -rf "$stage"
  echo 'Unable to install verified QA into frontend candidate' >&2
  exit 1
fi
if [ -d "$backup" ]; then rm -rf "$backup"; fi
echo 'NEBULA_R40_QA_PRESERVED: SHA-verified isolated QA survives frontend activation; production untouched'
