#!/usr/bin/env bash
# Roll back ONLY a failed preview route; never change R87/Omega/other OSgard games.
set -euo pipefail
run_id="${1:-}"
source_sha="${2:-}"
[[ "$run_id" =~ ^[0-9]{1,20}$ ]] || exit 2
[[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || exit 2
lock='/run/lock/osgard-frontend-activation.lock'
[ ! -L "$lock" ] && command -v flock >/dev/null 2>&1 || exit 3
exec 9>>"$lock"
flock -w 600 9 || exit 3
container='osgard-world'
games='/usr/share/nginx/html/games'
target="${games}/city-reign-preview"
backup="${games}/.city-reign-preview-backup-${run_id}"
failed="${games}/.city-reign-preview-candidate-${run_id}.failed"
docker inspect "$container" >/dev/null
docker exec -i "$container" sh -s -- "$target" "$backup" "$failed" "$source_sha" <<'SH'
set -eu
target="$1"; backup="$2"; failed="$3"; source_sha="$4"
[ -d "$target" ] && [ ! -L "$target" ] && [ ! -e "$failed" ] || exit 4
grep -Fq "\"source_commit\": \"${source_sha}\"" "$target/release.json" || exit 5
mv "$target" "$failed"
if [ -d "$backup" ]; then
  mv "$backup" "$target"
  (cd "$target" && sha256sum -c SHA256SUMS.txt)
  echo 'CITY REIGN PREVIEW: prior working version restored after failure'
else
  echo 'CITY REIGN PREVIEW: failed first preview isolated; existing Omega unchanged'
fi
SH
