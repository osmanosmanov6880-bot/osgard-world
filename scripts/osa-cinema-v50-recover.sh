#!/usr/bin/env bash
# Rehydrate an ALREADY approved live film if Docker frontend is later recreated.
# Never creates a new film release or authorization receipt.
set -Eeuo pipefail
umask 077
CONTAINER=osgard-world
TARGET=/var/lib/osgard-cinema-media
ROOT="$HOME/.local/share/osa-cinema-media"
DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
PIN="$DIR/../docs/OSA_CINEMA_V48_LOCAL_MEDIA_CANDIDATE_20261027.json"
PUBLISHER="$DIR/osa-cinema-v49-publisher.py"
exec 9>"$HOME/.osa-cinema-media-release.lock"
flock -n 9 || { echo 'FILM_RESTORE_SKIPPED: media operation in progress'; exit 0; }
if ! docker inspect "$CONTAINER" >/dev/null 2>&1 || [[ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER")" != true ]]; then
  echo 'FILM_RESTORE_SKIPPED: no running frontend'; exit 0
fi
MOUNT="$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/osgard-cinema-media"}}{{.Type}};{{.Source}};{{.RW}}{{end}}{{end}}' "$CONTAINER")"
if [[ -n "$MOUNT" ]]; then
  [[ "$MOUNT" =~ ^bind\;(/srv/[^;]+)\;false$ ]] || { echo 'FILM_RESTORE_HOLD: unexpected writable mount' >&2; exit 1; }
  echo 'FILM_RESTORE_SKIPPED: durable read-only mount already present'
  exit 0
fi
[[ -d "$ROOT" && ! -L "$ROOT" && -L "$ROOT/current" ]] || { echo 'FILM_RESTORE_SKIPPED: no durable active film'; exit 0; }
LINK="$(readlink "$ROOT/current")"
[[ "$LINK" =~ ^releases/(osa-v50-media-[0-9]{8,16})$ ]] || { echo 'FILM_RESTORE_HOLD: unexpected active film ID' >&2; exit 1; }
TAG="$(printf '%s' "$LINK" | cut -d/ -f2)"
SRC="$ROOT/releases/$TAG"
[[ -d "$SRC" && ! -L "$SRC" && -f "$SRC/release.json" && ! -L "$SRC/release.json" ]] || { echo 'FILM_RESTORE_SKIPPED: no approved receipt'; exit 0; }
python3 - "$SRC/release.json" "$TAG" <<'PY'
import json,sys
from pathlib import Path
p=json.loads(Path(sys.argv[1]).read_text())
assert p.get('schemaVersion')==1 and p.get('project')=='OSA CINEMA'
assert p.get('releaseId')==sys.argv[2] and p.get('status')=='PUBLIC_BROWSER_QA_PASS'
assert p.get('publicationAuthorized') is True and p.get('paidCheckoutEnabled') is False
assert p.get('assetCount')==8
assert p.get('fullRuSha256')=='c6e71377c2f4ecdcf8327c9ae213cd972a78ea6f97f9090945a7d18fad0fe751'
print('Existing approved receipt verified')
PY
python3 "$PUBLISHER" verify --source "$SRC" --pin "$PIN" >/dev/null
if docker exec "$CONTAINER" sh -c "test -e '$TARGET/current' || test -L '$TARGET/current'" >/dev/null 2>&1; then
  LIVE="$(docker exec "$CONTAINER" readlink "$TARGET/current" 2>/dev/null || true)"
  if [[ "$LIVE" == "releases/$TAG" ]] && docker exec "$CONTAINER" test -r "$TARGET/current/release.json"; then
    echo 'FILM_RESTORE_SKIPPED: same approved release already present'
    exit 0
  fi
  echo 'FILM_RESTORE_HOLD: different/partial film inside container' >&2
  exit 1
fi
if docker exec "$CONTAINER" test -e "$TARGET/releases/$TAG" >/dev/null 2>&1; then
  echo 'FILM_RESTORE_HOLD: partial same-ID film exists, no overwrite' >&2
  exit 1
fi
NGINX_CFG="$(docker exec "$CONTAINER" nginx -T 2>&1)"
[[ "$NGINX_CFG" == *'location ^~ /osa-cinema/premiere/'* ]] || { echo 'FILM_RESTORE_HOLD: no cinema Nginx route' >&2; exit 1; }
docker exec "$CONTAINER" mkdir -p "$TARGET/releases/$TAG"
docker cp "$SRC/." "$CONTAINER:$TARGET/releases/$TAG/"
docker exec "$CONTAINER" sh -c "cd '$TARGET/releases/$TAG' && sha256sum -c SHA256SUMS.txt >/dev/null"
HOST_SHA="$(sha256sum "$SRC/release.json" | awk '{print $1}')"
CONTAINER_SHA="$(docker exec "$CONTAINER" sha256sum "$TARGET/releases/$TAG/release.json" | awk '{print $1}')"
[[ "$HOST_SHA" == "$CONTAINER_SHA" ]] || { echo 'FILM_RESTORE_HOLD: receipt SHA differs' >&2; exit 1; }
docker exec "$CONTAINER" ln -s "releases/$TAG" "$TARGET/current"
if ! docker exec "$CONTAINER" nginx -t >/dev/null || ! docker exec "$CONTAINER" nginx -s reload >/dev/null; then
  docker exec "$CONTAINER" rm -f "$TARGET/current" || true
  echo 'FILM_RESTORE_HOLD: Nginx failed; host original preserved' >&2
  exit 1
fi
echo "RESTORED_PREVIOUSLY_APPROVED_FILM id=$TAG"
