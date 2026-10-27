#!/usr/bin/env bash
# Owner-authorized film, exact-byte first publication. No container recreation.
set -Eeuo pipefail
umask 077
ACTION="$1"
RUN_ID="$2"
[[ "$RUN_ID" =~ ^[0-9]{8,16}$ ]] || { echo 'Invalid run ID' >&2; exit 2; }
[[ "$ACTION" == stage || "$ACTION" == finalize || "$ACTION" == rollback ]] || { echo 'Invalid action' >&2; exit 2; }
DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
TAG="osa-v50-media-$RUN_ID"
CONTAINER=osgard-world
TARGET=/var/lib/osgard-cinema-media
PIN="$DIR/OSA_CINEMA_V48_LOCAL_MEDIA_CANDIDATE_20261027.json"
PUBLISHER="$DIR/osa-cinema-v49-publisher.py"
FINALIZER="$DIR/osa-cinema-v49-finalize.py"
ZIP="$DIR/OSA_CINEMA_V50_MEDIA_ONLY_20261027.zip"
ZIP_SHA=f501e1dec7e8ad83ac135e67ba99d16629246f0a4ca519e5ab2073b904724166
command -v python3 >/dev/null
command -v docker >/dev/null
command -v flock >/dev/null
docker inspect "$CONTAINER" >/dev/null
[[ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER")" == true ]]
[[ -f "$PIN" && -f "$PUBLISHER" ]]
exec 9>"$HOME/.osa-cinema-media-release.lock"
flock -n 9 || { echo 'Another film release is running' >&2; exit 1; }
MOUNT="$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/osgard-cinema-media"}}{{.Type}};{{.Source}};{{.RW}}{{end}}{{end}}' "$CONTAINER")"
if [[ -z "$MOUNT" ]]; then
  MODE=mirror
  ROOT="$HOME/.local/share/osa-cinema-media"
  mkdir -p "$ROOT"
elif [[ "$MOUNT" =~ ^bind\;(/srv/[^;]+)\;false$ ]]; then
  MODE=bind
  ROOT="$(printf '%s' "$MOUNT" | cut -d';' -f2)"
  [[ -d "$ROOT" && -w "$ROOT" ]] || { echo 'Bind source is not writable by deploy user' >&2; exit 1; }
else
  echo 'Unexpected or writable film mount; refusing production changes' >&2
  exit 1
fi

if [[ "$ACTION" == stage ]]; then
  [[ ! -e "$ROOT/current" && ! -L "$ROOT/current" ]] || { echo 'A film release is already active; review replacement separately' >&2; exit 1; }
  if docker exec "$CONTAINER" sh -c "test -e '$TARGET/current' || test -L '$TARGET/current'" >/dev/null 2>&1; then
    echo 'A different film is active in the container' >&2; exit 1
  fi
  CURRENT_NGINX="$(docker exec "$CONTAINER" nginx -T 2>&1)"
  [[ "$CURRENT_NGINX" == *'location ^~ /osa-cinema/premiere/'* ]] || { echo 'Premiere Nginx location absent' >&2; exit 1; }
  [[ -f "$ZIP" && "$(sha256sum "$ZIP" | awk '{print $1}')" == "$ZIP_SHA" ]] || { echo 'Media ZIP missing or wrong hash' >&2; exit 1; }
  FREE="$(df -Pm "$HOME" | awk 'NR==2 {print $4}')"
  [[ "$FREE" =~ ^[0-9]+$ ]] && (( FREE >= 950 )) || { echo 'VPS free disk below safe 950 MiB threshold' >&2; exit 1; }
  if [[ "$MODE" == mirror ]]; then
    CONTAINER_FREE="$(docker exec "$CONTAINER" df -Pm /tmp | awk 'NR==2 {print $4}')"
    [[ "$CONTAINER_FREE" =~ ^[0-9]+$ ]] && (( CONTAINER_FREE >= 350 )) || { echo 'Container free disk below safe threshold' >&2; exit 1; }
  fi
  mkdir -p "$DIR/unpacked"
  python3 - "$ZIP" "$DIR/unpacked" <<'PYZIP'
import sys, zipfile
from pathlib import Path
src,dest=map(Path,sys.argv[1:3])
names=['index.html','manifest.json','SHA256SUMS.txt','assets/osa-premiere-poster.jpg']
names += [f'masters/osa-v48-{part}-{lang}.mp4' for part in ('directors','trailer') for lang in ('ru','en')]
names += [f'captions/osa-v48-{part}-{lang}.vtt' for part in ('directors','trailer') for lang in ('ru','en')]
allowed={f'film/{name}' for name in names}
with zipfile.ZipFile(src) as z:
    files=z.infolist()
    if len(files)!=12 or {f.filename for f in files}!=allowed or z.testzip():
        raise SystemExit('Unexpected, duplicated or corrupted owner-media ZIP members')
    if any(f.external_attr>>16 & 0o170000==0o120000 for f in files):
        raise SystemExit('Refusing symlink in media ZIP')
    z.extractall(dest)
print('Owner media ZIP contains 12 allowed regular files')
PYZIP
  python3 "$PUBLISHER" verify --source "$DIR/unpacked/film" --pin "$PIN"
  python3 "$PUBLISHER" stage --source "$DIR/unpacked/film" --pin "$PIN" --root "$ROOT" --release-id "$TAG"
  HOST_ACTIVE=0
  CONTAINER_ACTIVE=0
  recover_failed_stage() {
    if [[ "$CONTAINER_ACTIVE" == 1 && "$MODE" == mirror ]]; then
      docker exec "$CONTAINER" sh -c "if [ \"\$(readlink '$TARGET/current' 2>/dev/null)\" = 'releases/$TAG' ]; then rm '$TARGET/current'; fi" || true
    fi
    if [[ "$HOST_ACTIVE" == 1 && "$(readlink "$ROOT/current" 2>/dev/null || true)" == "releases/$TAG" ]]; then
      python3 "$PUBLISHER" rollback --root "$ROOT" || true
    fi
  }
  trap recover_failed_stage ERR
  if [[ "$MODE" == mirror ]]; then
    docker exec "$CONTAINER" sh -c "mkdir -p '$TARGET/releases/$TAG'"
    docker cp "$ROOT/releases/$TAG/." "$CONTAINER:$TARGET/releases/$TAG/"
    docker exec "$CONTAINER" sh -c "cd '$TARGET/releases/$TAG' && sha256sum -c SHA256SUMS.txt >/dev/null"
  fi
  python3 "$PUBLISHER" activate --root "$ROOT" --pin "$PIN" --release-id "$TAG"
  HOST_ACTIVE=1
  if [[ "$MODE" == mirror ]]; then
    docker exec "$CONTAINER" sh -c "ln -s 'releases/$TAG' '$TARGET/current'"
    CONTAINER_ACTIVE=1
  fi
  docker exec "$CONTAINER" nginx -t >/dev/null
  docker exec "$CONTAINER" nginx -s reload >/dev/null
  trap - ERR
  echo "MEDIA_STAGED_AWAITING_REAL_HTTPS_AND_BROWSER_QA run=$RUN_ID mode=$MODE"
  exit 0
fi

if [[ "$ACTION" == rollback ]]; then
  if [[ "$MODE" == mirror ]]; then
    docker exec "$CONTAINER" sh -c "if [ \"\$(readlink '$TARGET/current' 2>/dev/null)\" = 'releases/$TAG' ]; then rm '$TARGET/current'; fi"
  fi
  if [[ "$(readlink "$ROOT/current" 2>/dev/null || true)" == "releases/$TAG" ]]; then
    python3 "$PUBLISHER" rollback --root "$ROOT"
  fi
  docker exec "$CONTAINER" nginx -s reload >/dev/null
  echo 'ROLLED_BACK_THIS_RELEASE_IF_ACTIVE'
  exit 0
fi

[[ "$(readlink "$ROOT/current" 2>/dev/null || true)" == "releases/$TAG" ]] || { echo 'Wrong active release' >&2; exit 1; }
[[ -f "$DIR/production-http.json" && -f "$DIR/production-browser.json" && -f "$FINALIZER" ]] || { echo 'Real production proofs absent' >&2; exit 1; }
python3 "$FINALIZER" --root "$ROOT" --release-id "$TAG" --pin "$PIN" \
  --http-report "$DIR/production-http.json" --browser-report "$DIR/production-browser.json" \
  --publisher-acknowledgment I_APPROVE_THE_PUBLIC_OSA_FILM
if [[ "$MODE" == mirror ]]; then
  docker cp "$ROOT/releases/$TAG/release.json" "$CONTAINER:$TARGET/releases/$TAG/release.json"
  H_SHA="$(sha256sum "$ROOT/releases/$TAG/release.json" | awk '{print $1}')"
  C_SHA="$(docker exec "$CONTAINER" sha256sum "$TARGET/releases/$TAG/release.json" | awk '{print $1}')"
  [[ "$H_SHA" == "$C_SHA" ]] || { echo 'Final receipt content mismatch' >&2; exit 1; }
fi
docker exec "$CONTAINER" nginx -t >/dev/null
docker exec "$CONTAINER" nginx -s reload >/dev/null
echo "PUBLIC_RECEIPT_INSTALLED run=$RUN_ID mode=$MODE"
