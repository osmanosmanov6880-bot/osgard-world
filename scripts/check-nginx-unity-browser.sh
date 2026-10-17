#!/usr/bin/env bash
set -euo pipefail

# CI-only real engine validation through the production Nginx configuration.
# The default publishing workflow may run this same gate before SSH activation.
checkout_dir="$(pwd)"
candidate_dir="$(mktemp -d)"
candidate_name="osgard-unity-browser-${GITHUB_RUN_ID:-ci}-$$"
cleanup() {
  docker logs "$candidate_name" > unity-test-results/nginx.log 2>&1 || true
  docker rm -f "$candidate_name" >/dev/null 2>&1 || true
  rm -rf "$candidate_dir"
}
trap cleanup EXIT
mkdir -p unity-test-results
test -s dist/games/remix/player/Build/REMIX-webgl3.wasm.gz
sed 's/__OSGARD_HOST_GATEWAY__/127.0.0.1/g' nginx.conf > "$candidate_dir/default.conf"
docker run --detach --name "$candidate_name" \
  --add-host remix-api:127.0.0.1 \
  --publish 127.0.0.1::80 \
  --mount "type=bind,src=$checkout_dir/dist,dst=/usr/share/nginx/html,readonly" \
  --mount "type=bind,src=$candidate_dir/default.conf,dst=/etc/nginx/conf.d/default.conf,readonly" \
  nginx:1.27-alpine >/dev/null
candidate_port="$(docker inspect --format '{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' "$candidate_name")"
for attempt in $(seq 1 15); do
  if curl --silent --fail "http://127.0.0.1:$candidate_port/" >/dev/null; then break; fi
  sleep 1
done
docker exec "$candidate_name" nginx -t
OSGARD_BASE_URL="http://127.0.0.1:$candidate_port" node scripts/game-delivery-http-smoke.mjs dist
OSGARD_UNITY_BASE_URL="http://127.0.0.1:$candidate_port" npx playwright test --config playwright.remix-unity.config.mjs "$@"
