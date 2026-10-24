#!/usr/bin/env bash
# Replace only the verified native OSGARD game, preserving the rest of the site.
set -euo pipefail
run_id="${1:?GitHub run id is required}"
case "$run_id" in *[!0-9]*|'') echo "Invalid run id" >&2; exit 2;; esac
# Serialize with the full-site atomic HTML swap: otherwise the older site
# release can overwrite the freshly validated native engine mid-flight.
lock_path="/run/lock/osgard-frontend-activation.lock"
if [ -L "$lock_path" ] || ! command -v flock >/dev/null 2>&1; then
  echo 'Trusted shared OSGARD activation lock is unavailable' >&2; exit 1
fi
exec 9>>"$lock_path"
if ! flock -w 600 9; then
  echo 'Timed out waiting for the shared OSGARD activation lock' >&2; exit 1
fi
root="/tmp/osgard-omega-native-${run_id}"
container='osgard-world'
game_root='/usr/share/nginx/html/games'
candidate="${game_root}/.omega-candidate-${run_id}"
previous="${game_root}/.omega-backup-${run_id}"
target="${game_root}/omega-3d-preview"
test -s "${root}/game.tgz"
mkdir -p "${root}/unpacked"
tar -xzf "${root}/game.tgz" -C "${root}/unpacked"
(cd "${root}/unpacked" && sha256sum -c SHA256SUMS.txt)
test -s "${root}/unpacked/index.wasm"
test -s "${root}/unpacked/index.pck"
docker inspect "$container" >/dev/null
docker exec "$container" sh -c "mkdir -p '$candidate'"
docker cp "${root}/unpacked/." "${container}:${candidate}/"
docker exec "$container" sh -c "cd '$candidate' && sha256sum -c SHA256SUMS.txt && test -s index.html && test -s index.wasm && test -s index.pck"
docker exec -i "$container" sh -s -- "$candidate" "$target" "$previous" <<'CONTAINER'
set -eu
candidate="$1"
target="$2"
previous="$3"
test -d "$candidate" && test -s "$candidate/index.wasm"
if [ -e "$target" ]; then
  test ! -e "$previous"
  mv "$target" "$previous"
fi
if ! mv "$candidate" "$target"; then
  if [ -e "$previous" ]; then mv "$previous" "$target"; fi
  exit 1
fi
if ! (cd "$target" && sha256sum -c SHA256SUMS.txt >/dev/null); then
  rm -rf "$target"
  if [ -e "$previous" ]; then mv "$previous" "$target"; fi
  exit 1
fi
echo 'PASS: Native Godot game activated inside OSGARD Nginx container'
CONTAINER
docker exec "$container" sh -c "test -s '$target/index.wasm' && test -s '$target/index.pck' && grep -q 'Godot 4.4.1' '$target/release.json'"
echo 'PASS: OSGARD Nginx container contains exact SHA-verified native Web export'