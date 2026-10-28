#!/usr/bin/env bash
# CITY REIGN: isolated, source-verified native Godot WebGL rollout to the
# existing OSGARD Nginx container. Never edit the older omega-3d-preview.
set -euo pipefail
mode="$1"
run_id="$2"
source_sha="$3"
case "$run_id" in ''|*[!0-9]*) echo 'Invalid numeric release run id' >&2; exit 2;; esac
test "${#run_id}" -le 20 || { echo 'Oversized run id' >&2; exit 2; }
case "$source_sha" in ''|*[!0-9a-f]*) echo 'Invalid source commit' >&2; exit 2;; esac
test "${#source_sha}" -eq 40 || { echo 'Invalid source SHA length' >&2; exit 2; }
case "$mode" in activate|rollback|cleanup) ;; *) echo 'Invalid release operation' >&2; exit 2;; esac

stage="/tmp/osgard-city-reign-$run_id"
container='osgard-world'
games='/usr/share/nginx/html/games'
candidate="$games/.city-reign-candidate-$run_id"
previous="$games/.city-reign-backup-$run_id"
failed="$games/.city-reign-failed-$run_id"
target="$games/city-reign"
lock_path='/run/lock/osgard-frontend-activation.lock'

if [ -L "$lock_path" ] || ! command -v flock >/dev/null 2>&1; then
  echo 'Original OSGARD site activation lock unavailable' >&2
  exit 3
fi
exec 9>>"$lock_path"
flock -w 600 9 || { echo 'OSGARD release lock acquisition failed' >&2; exit 3; }

if [ "$mode" = cleanup ]; then
  # Staging cleanup cannot access the website or another release directory.
  if [ ! -e "$stage" ]; then exit 0; fi
  [ ! -L "$stage" ] && [ -d "$stage" ] && [ -s "$stage/game.tgz" ] || exit 4
  rm -rf -- "$stage"
  echo 'CITY REIGN: source-locked release transport cleaned'
  exit 0
fi

docker inspect "$container" >/dev/null
docker exec "$container" test -d "$games"

if [ "$mode" = rollback ]; then
  # Only this release channel is eligible for rollback. Preserve any older
  # unrelated OSGARD frontend, Omega 3D preview and all other game routes.
  docker exec -i "$container" sh -s -- "$target" "$previous" "$failed" <<'REMOTE'
set -eu
target="$1"; previous="$2"; failed="$3"
test ! -L "$target" && test ! -L "$previous" && test ! -e "$failed"
if [ -e "$target" ]; then
  test -f "$target/release.json"
  grep -Fq '"channel": "city-reign-preview"' "$target/release.json"
  mv "$target" "$failed"
fi
if [ -d "$previous" ]; then
  mv "$previous" "$target"
  (cd "$target" && sha256sum -c SHA256SUMS.txt >/dev/null)
fi
echo 'CITY REIGN: ONLY the isolated game route rolled back'
REMOTE
  exit 0
fi

[ -d "$stage" ] && [ ! -L "$stage" ] && [ -s "$stage/game.tgz" ] || {
  echo 'Source-locked transport not staged' >&2; exit 4;
}
mkdir -p "$stage/unpacked"
# This is a CI-created flat set of first-party Godot binaries, not a package
# manager or script downloaded from an unrelated online service.
if tar -tf "$stage/game.tgz" | grep -E '(^/|(^|/)\.\.(/|$))'; then
  echo 'Unsafe archive paths; refusing release' >&2; exit 4
fi
tar -xzf "$stage/game.tgz" -C "$stage/unpacked"
(
 cd "$stage/unpacked"
 test -s index.html && test -s index.js && test -s index.wasm && test -s index.pck
 test -s release.json && test -s SHA256SUMS.txt
 sha256sum -c SHA256SUMS.txt >/dev/null
 grep -Fq '"channel": "city-reign-preview"' release.json
 grep -Fq "\"source_commit\": \"$source_sha\"" release.json
)
# Never replace a foreign game or a symlink with a similar directory name.
docker exec -i "$container" sh -s -- "$target" "$candidate" "$previous" <<'CHECK'
set -eu
target="$1"; candidate="$2"; previous="$3"
test ! -L "$target" && test ! -e "$candidate" && test ! -e "$previous"
if [ -e "$target" ]; then
 test -d "$target" && test -f "$target/release.json"
 grep -Fq '"channel": "city-reign-preview"' "$target/release.json"
fi
CHECK

docker exec "$container" mkdir "$candidate"
docker cp "$stage/unpacked/." "$container:$candidate/"
docker exec -i "$container" sh -s -- "$candidate" "$target" "$previous" <<'COMMIT'
set -eu
candidate="$1"; target="$2"; previous="$3"
(cd "$candidate" && sha256sum -c SHA256SUMS.txt >/dev/null)
test -s "$candidate/index.wasm" && test -s "$candidate/index.pck"
if [ -d "$target" ]; then
  mv "$target" "$previous"
fi
if ! mv "$candidate" "$target"; then
  if [ -d "$previous" ]; then mv "$previous" "$target"; fi
  exit 5
fi
if ! (cd "$target" && sha256sum -c SHA256SUMS.txt >/dev/null); then
  mv "$target" "$candidate"
  if [ -d "$previous" ]; then mv "$previous" "$target"; fi
  exit 5
fi
echo 'CITY REIGN: live route atomically activated inside original OSGARD Nginx'
COMMIT
echo "CITY REIGN release source verified: $source_sha"
