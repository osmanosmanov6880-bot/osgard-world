#!/bin/sh
# Safeguard against stale full-platform bundles replacing a newer Godot release.
# Runs INSIDE the existing Nginx container, before the frontend candidate is
# swapped into place and while the same host activation lock is held.
set -eu

active="${1:?existing active game directory required}"
candidate="${2:?candidate game directory required}"
case "$active:$candidate" in /*:/*) ;; *) echo 'Omega preserve requires two absolute paths' >&2; exit 2;; esac
[ "$active" != "$candidate" ] && [ "$active" != "/" ] && [ "$candidate" != "/" ] || exit 2
[ ! -L "$active" ] && [ ! -L "$candidate" ] || {
  echo 'Omega preservation refuses symlink targets' >&2
  exit 2
}

# A normal frontend release can introduce the first native game. Once the
# independent SHA-attested publisher has installed it, the site-wide deploy
# must NEVER reintroduce older binaries from a stale frontend checkout.
if [ ! -s "$active/SHA256SUMS.txt" ]; then
  echo 'No independently attested active Omega; keep bundled candidate'
  exit 0
fi

for required in index.html index.js index.wasm index.pck release.json; do
  if [ ! -s "$active/$required" ]; then
    echo "Attested active Omega is missing $required" >&2
    exit 1
  fi
done
if ! grep -q 'Godot 4.4.1' "$active/release.json" ||
   ! grep -q 'native-Godot-HTML5-export' "$active/release.json" ||
   ! (cd "$active" && sha256sum -c SHA256SUMS.txt >/dev/null 2>&1); then
  echo 'Refusing frontend activation: active Omega SHA attestation is invalid' >&2
  exit 1
fi

# Copy+verify BEFORE removing a candidate's bundled older game. Every
# failure leaves the candidate untouched so the enclosing deploy can rollback.
stage="${candidate}.verified-$$"
[ ! -e "$stage" ] || exit 2
mkdir -p "$(dirname "$candidate")"
if ! cp -a "$active" "$stage"; then
  rm -rf "$stage"
  exit 1
fi
if ! (cd "$stage" && sha256sum -c SHA256SUMS.txt >/dev/null 2>&1); then
  rm -rf "$stage"
  echo 'Freshly copied Omega files failed SHA verification' >&2
  exit 1
fi
rm -rf "$candidate"
mv "$stage" "$candidate"
echo 'PASS: preserved current SHA-attested native Omega during full-site release'
