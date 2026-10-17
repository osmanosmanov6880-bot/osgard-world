#!/usr/bin/env bash
set -euo pipefail

# CI-only integration: original test fixture -> production guard -> real Nginx.
# Every container, network and volume is isolated from a deployment.
checkout_dir="$(pwd)"
candidate_dir="$(mktemp -d)"
check_id="osgard-remix-check-${GITHUB_RUN_ID:-local}-$$"
frontend_network="$check_id-front"
upstream_network="$check_id-upstream"
guard_name="$check_id-guard"
fixture_name="$check_id-fixture"
nginx_name="$check_id-nginx"
result_volume="$check_id-results"
guard_image="osgard-remix-guard:qa-${GITHUB_RUN_ID:-local}-$$"
cleanup() {
  docker rm -f "$nginx_name" "$guard_name" "$fixture_name" >/dev/null 2>&1 || true
  docker network rm "$frontend_network" "$upstream_network" >/dev/null 2>&1 || true
  docker volume rm "$result_volume" >/dev/null 2>&1 || true
  rm -rf "$candidate_dir"
}
trap cleanup EXIT

test -s dist/index.html
docker build -f server/RemixGuard.Dockerfile -t "$guard_image" .
docker network create "$frontend_network" >/dev/null
docker network create "$upstream_network" >/dev/null
docker volume create "$result_volume" >/dev/null
docker run --detach --name "$fixture_name" --network "$upstream_network" --network-alias remix-api \
  --read-only --cap-drop ALL --security-opt no-new-privileges \
  --mount "type=bind,src=$checkout_dir,dst=/source,readonly" \
  "$guard_image" python /source/scripts/remix-guard-fixture.py --host 0.0.0.0 --port 8080 >/dev/null

start_guard() {
  docker run --detach --name "$guard_name" --network "$frontend_network" --network-alias remix-guard \
    --read-only --init --cap-drop ALL --security-opt no-new-privileges \
    --pids-limit 96 --memory 128m --cpus 0.5 --tmpfs /tmp:size=4m,noexec,nosuid \
    --mount "type=volume,src=$result_volume,dst=/var/lib/remix-guard" "$guard_image" >/dev/null
  docker network connect "$upstream_network" "$guard_name"
}
fixture_phase() {
  docker exec "$fixture_name" python -c \
    "import urllib.request; urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:8080/__fixture/$1', data=b'{}', headers={'Content-Type':'application/json'}), timeout=4).read()"
}
start_guard
sed 's/__OSGARD_HOST_GATEWAY__/127.0.0.1/g' nginx.conf > "$candidate_dir/default.conf"
docker run --detach --name "$nginx_name" --network "$frontend_network" \
  --publish 127.0.0.1::80 \
  --mount "type=bind,src=$checkout_dir/dist,dst=/usr/share/nginx/html,readonly" \
  --mount "type=bind,src=$candidate_dir/default.conf,dst=/etc/nginx/conf.d/default.conf,readonly" \
  nginx:1.27-alpine >/dev/null
candidate_port="$(docker inspect --format '{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' "$nginx_name")"
candidate_base="http://127.0.0.1:$candidate_port/api/remix"
wait_ready() {
  for _ in $(seq 1 25); do
    if curl --max-time 8 --silent --fail "$candidate_base/health" | grep -q 'osgard-remix-guard'; then return; fi
    sleep 1
  done
  docker logs "$guard_name" >&2
  docker logs "$nginx_name" >&2
  return 1
}
wait_ready
docker exec "$nginx_name" nginx -t
fixture_phase countdown
python3 scripts/remix-guard-gateway-smoke.py "$candidate_base" countdown "$candidate_dir/snapshot.json"
fixture_phase playing
python3 scripts/remix-guard-gateway-smoke.py "$candidate_base" playing "$candidate_dir/snapshot.json"
fixture_phase terminal
python3 scripts/remix-guard-gateway-smoke.py "$candidate_base" finalized "$candidate_dir/snapshot.json"

# Regress the mutable fixture before replacement. A missing result volume must
# fail this gate rather than silently refreeze an identical upstream response.
fixture_phase playing
# Recreate the service process/container, retaining only the named result volume.
docker rm -f "$guard_name" >/dev/null
start_guard
wait_ready
python3 scripts/remix-guard-gateway-smoke.py "$candidate_base" restored "$candidate_dir/snapshot.json"
docker stop "$fixture_name" >/dev/null
python3 scripts/remix-guard-gateway-smoke.py "$candidate_base" offline "$candidate_dir/snapshot.json"
echo 'PASS real Nginx prefix/query routing, phase gate, durable result volume, guard replacement and upstream outage (isolated HTTP fixture).'
