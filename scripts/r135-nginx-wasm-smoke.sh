#!/usr/bin/env bash
set -euo pipefail
# Real Nginx + actual SHA-verified WebGL HTML/WASM/PCK. No production mutation.
# Usage: bash scripts/r135-nginx-wasm-smoke.sh /path/to/verified/r135/web
source_dir="${1:-dist/games/r135-service}"
test -s "$source_dir/index.html"
test -s "$source_dir/index.wasm"
test -s "$source_dir/index.wasm.gz"
test -s "$source_dir/index.pck"
test -s "$source_dir/release.json"
abs_dir="$(cd "$source_dir" && pwd)"
candidate_dir="$(mktemp -d)"
container_name="osgard-r135-wasm-qa-${GITHUB_RUN_ID:-local}-$$"
cleanup() {
  docker rm -f "$container_name" >/dev/null 2>&1 || true
  rm -rf "$candidate_dir"
}
trap cleanup EXIT
sed 's/__OSGARD_HOST_GATEWAY__/127.0.0.1/g' nginx.conf > "$candidate_dir/default.conf"
docker run --detach --name "$container_name" \
  --add-host remix-api:127.0.0.1 \
  --publish 127.0.0.1::80 \
  --mount "type=bind,src=$abs_dir,dst=/usr/share/nginx/html/games/r135-service,readonly" \
  --mount "type=bind,src=$candidate_dir/default.conf,dst=/etc/nginx/conf.d/default.conf,readonly" \
  nginx:1.27-alpine >/dev/null
port="$(docker inspect --format '{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' "$container_name")"
for attempt in $(seq 1 15); do
  if curl --max-time 3 -sS -f "http://127.0.0.1:$port/games/r135-service/index.html" -o /dev/null; then
    break
  fi
  if [ "$attempt" -eq 15 ]; then
    docker logs "$container_name" >&2
    exit 1
  fi
  sleep 1
done
docker exec "$container_name" nginx -t
OSGARD_BASE_URL="http://127.0.0.1:$port" OSGARD_REQUIRE_GZIP=1 node scripts/r135-production-smoke.mjs
echo "R135 candidate Nginx: original Godot HTML, gzip WASM, correct MIME, verified PCK range PASS"
