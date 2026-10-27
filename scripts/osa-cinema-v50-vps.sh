#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ACTION="$1"
RUN_ID="$2"
[[ "$RUN_ID" =~ ^[0-9]{8,16}$ ]] || { echo 'invalid run ID' >&2; exit 2; }
[[ "$ACTION" == stage || "$ACTION" == rollback || "$ACTION" == finalize ]] || exit 2
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
flock -n 9 || { echo 'another media operation in progress' >&2; exit 1; }
MOUNT="$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/osgard-cinema-media"}}{{.Type}};{{.Source}};{{.RW}}{{end}}{{end}}' "$CONTAINER")"
if [[ -z "$MOUNT" ]]; then
  MODE=mirror
  ROOT="$HOME/.local/share/osa-cinema-media"
  mkdir -p "$ROOT"
elif [[ "$MOUNT" =~ ^bind\;(/srv/[^;]+)\;false$ ]]; then
  MODE=bind
  ROOT="$(printf '%s' "$MOUNT" | cut -d';' -f2)"
  [[ -d "$ROOT" && -w "$ROOT" ]] || { echo 'bind root not writable' >&2; exit 1; }
else
  echo 'unexpected Docker mount, fail closed' >&2
  exit 1
fi
if [[ "$ACTION" == stage ]]; then
  [[ ! -e "$ROOT/current" && ! -L "$ROOT/current" ]] || { echo 'existing release: require separate review' >&2; exit 1; }
  if docker exec "$CONTAINER" sh -c "test -e '$TARGET/current' || test -L '$TARGET/current'" >/dev/null 2>&1; then
    echo 'existing frontend release: require separate review' >&2
    exit 1
  fi
  [[ -f "$ZIP" ]] && [[ "$(sha256sum "$ZIP" | awk '{print $1}')" == "$ZIP_SHA" ]] || { echo 'media ZIP missing or wrong hash' >&2; exit 1; }
  FREE="$(df -Pm "$HOME" | awk 'NR==2 {print $4}')"
  [[ "$FREE" =~ ^[0-9]+$ ]] && (( FREE >= 950 )) || { echo 'insufficient VPS disk capacity' >&2; exit 1; }
  mkdir -p "$DIR/unpacked"
  python3 -m zipfile -e "$ZIP" "$DIR/unpacked"
  [[ -f "$DIR/unpacked/film/SHA256SUMS.txt" ]] || { echo 'unexpected media ZIP content' >&2; exit 1; }
  python3 "$PUBLISHER" verify --source "$DIR/unpacked/film" --pin "$PIN"
  python3 "$PUBLISHER" stage --source "$DIR/unpacked/film" --pin "$PIN" --root "$ROOT" --release-id "$TAG"
  HOST_ACTIVE=0
  CONTAINER_ACTIVE=0
  recover() {
    if [[ "$CONTAINER_ACTIVE" == 1 && "$MODE" == mirror ]]; then
      docker exec "$CONTAINER" sh -c "if [ \"\$(readlink '$TARGET/current' 2>/dev/null)\" = 'releases/$TAG' ]; then rm '$TARGET/current'; fi" || true
    fi
    if [[ "$HOST_ACTIVE" == 1 && "$(readlink "$ROOT/current" 2>/dev/null || true)" == "releases/$TAG" ]]; then
      python3 "$PUBLISHER" rollback --root "$ROOT" || true
    fi
  }
  trap recover ERR
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
  printf 'STAGED_AND_ROUTED_AWAITING_PUBLIC_QA run_id=%s mode=%s\n' "$RUN_ID" "$MODE"
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
  echo 'ROLLED_BACK_IF_ACTIVE'
  exit 0
fi
if [[ "$ACTION" == finalize ]]; then
  [[ "$(readlink "$ROOT/current" 2>/dev/null || true)" == "releases/$TAG" ]] || { echo 'wrong active film' >&2; exit 1; }
  [[ -f "$DIR/production-http.json" && -f "$DIR/production-browser.json" && -f "$FINALIZER" ]] || { echo 'missing real QA reports' >&2; exit 1; }
  python3 "$FINALIZER" --root "$ROOT" --release-id "$TAG" \
    --pin "$PIN" --http-report "$DIR/production-http.json" \
    --browser-report "$DIR/production-browser.json" \
    --publisher-acknowledgment I_APPROVE_THE_PUBLIC_OSA_FILM
  if [[ "$MODE" == mirror ]]; then
    docker cp "$ROOT/releases/$TAG/release.json" "$CONTAINER:$TARGET/releases/$TAG/release.json"
    HOST_SHA="$(sha256sum "$ROOT/releases/$TAG/release.json" | awk '{print $1}')"
    CONTAINER_SHA="$(docker exec "$CONTAINER" sha256sum "$TARGET/releases/$TAG/release.json" | awk '{print $1}')"
    [[ "$HOST_SHA" == "$CONTAINER_SHA" ]] || { echo 'receipt mismatch' >&2; exit 1; }
  fi
  docker exec "$CONTAINER" nginx -t >/dev/null
  docker exec "$CONTAINER" nginx -s reload >/dev/null
  printf 'PUBLIC_RECEIPT_INSTALLED release_id=%s mode=%s\n' "$TAG" "$MODE"
fi
