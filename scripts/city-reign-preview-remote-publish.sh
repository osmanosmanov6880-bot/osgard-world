#!/usr/bin/env bash
# Publish ONLY public CITY REIGN preview via SSH; preserve Omega R87 and all other services.
set -euo pipefail
run_id="${1:-}"
source_sha="${2:-}"
[[ "$run_id" =~ ^[0-9]{1,20}$ ]] || { echo 'Invalid run id' >&2; exit 2; }
[[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid immutable source SHA' >&2; exit 2; }
lock='/run/lock/osgard-frontend-activation.lock'
if [ -L "$lock" ] || ! command -v flock >/dev/null 2>&1; then
  echo 'Shared OSGARD activation lock not trusted' >&2; exit 2
fi
exec 9>>"$lock"
flock -w 600 9 || { echo 'Unable to obtain shared activation lock' >&2; exit 3; }
root="/tmp/osgard-city-reign-preview-${run_id}"
container='osgard-world'
games='/usr/share/nginx/html/games'
candidate="${games}/.city-reign-preview-candidate-${run_id}"
backup="${games}/.city-reign-preview-backup-${run_id}"
target="${games}/city-reign-preview"
[ ! -L "$root" ] && [ -f "$root/game.tgz" ] && [ -s "$root/game.tgz" ] || {
  echo 'Missing or untrusted isolated transport staging' >&2; exit 3;
}
mkdir -p "$root/unpacked"
tar -xzf "$root/game.tgz" -C "$root/unpacked" --no-same-owner --no-same-permissions
(cd "$root/unpacked" && sha256sum -c SHA256SUMS.txt)
for required in index.html index.js index.wasm index.pck release.json; do
  test -s "$root/unpacked/$required" || { echo "Required $required missing" >&2; exit 3; }
done
grep -Fq "\"source_commit\": \"${source_sha}\"" "$root/unpacked/release.json" || {
  echo 'Pinned source SHA does not match release manifest' >&2; exit 3;
}
grep -Fq '"engine": "Godot 4.4.1"' "$root/unpacked/release.json" || exit 3
docker inspect "$container" >/dev/null
docker exec -i "$container" sh -s -- "$games" "$candidate" "$backup" "$target" <<'SH'
set -eu
games="$1"; candidate="$2"; backup="$3"; target="$4"
[ -d "$games" ] && [ ! -L "$games" ] || exit 5
[ ! -e "$candidate" ] && [ ! -L "$candidate" ] || exit 5
[ ! -e "$backup" ] && [ ! -L "$backup" ] || exit 5
[ ! -L "$target" ] || exit 5
mkdir "$candidate"
SH
docker cp "$root/unpacked/." "$container:$candidate/"
docker exec -i "$container" sh -s -- "$candidate" "$backup" "$target" "$source_sha" <<'SH'
set -eu
candidate="$1"; backup="$2"; target="$3"; source_sha="$4"
[ ! -L "$candidate" ] && [ -d "$candidate" ] || exit 6
(cd "$candidate" && sha256sum -c SHA256SUMS.txt)
grep -Fq "\"source_commit\": \"${source_sha}\"" "$candidate/release.json" || exit 6
for file in index.html index.js index.wasm index.pck; do test -s "$candidate/$file"; done
if [ -e "$target" ]; then
  [ -d "$target" ] && [ ! -L "$target" ] || exit 6
  mv "$target" "$backup"
fi
if ! mv "$candidate" "$target"; then
  if [ -d "$backup" ]; then mv "$backup" "$target"; fi
  exit 7
fi
if ! (cd "$target" && sha256sum -c SHA256SUMS.txt >/dev/null); then
  failed="${candidate}.failed"
  mv "$target" "$failed"
  if [ -d "$backup" ]; then mv "$backup" "$target"; fi
  exit 7
fi
printf 'CITY_REIGN_PREVIEW_SSH_ACTIVATED source=%s route=/games/city-reign-preview/\n' "$source_sha"
SH
