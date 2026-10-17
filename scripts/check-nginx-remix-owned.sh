#!/usr/bin/env bash
set -euo pipefail

# Real candidate containers and Nginx, with disposable Core/REMIX data only.
checkout_dir="$(pwd)"
candidate_dir="$(mktemp -d)"
check_id="osgard-owned-check-${GITHUB_RUN_ID:-local}-$$"
frontend_network="$check_id-front"
upstream_network="$check_id-upstream"
guard_name="$check_id-guard"
core_name="$check_id-core"
fixture_name="$check_id-fixture"
nginx_name="$check_id-nginx"
result_volume="$check_id-results"
core_volume="$check_id-accounts"
guard_image="osgard-remix-guard:owned-qa-${GITHUB_RUN_ID:-local}-$$"
core_image="osgard-core-api:owned-qa-${GITHUB_RUN_ID:-local}-$$"
cleanup() {
  docker rm -f "$nginx_name" "$guard_name" "$core_name" "$fixture_name" >/dev/null 2>&1 || true
  docker network rm "$frontend_network" "$upstream_network" >/dev/null 2>&1 || true
  docker volume rm "$result_volume" "$core_volume" >/dev/null 2>&1 || true
  rm -rf "$candidate_dir"
}
trap cleanup EXIT

test -s dist/index.html
docker build -f server/RemixGuard.Dockerfile -t "$guard_image" .
docker build -f server/Dockerfile -t "$core_image" .
docker network create "$frontend_network" >/dev/null
docker network create "$upstream_network" >/dev/null
docker volume create "$result_volume" >/dev/null
docker volume create "$core_volume" >/dev/null
docker run --detach --name "$core_name" --network "$frontend_network" --network-alias core-api \
  --read-only --init --cap-drop ALL --security-opt no-new-privileges \
  --pids-limit 128 --memory 768m --cpus 1.0 --tmpfs /tmp:size=16m,noexec,nosuid \
  --mount "type=volume,src=$core_volume,dst=/var/lib/osgard-core" "$core_image" >/dev/null
docker run --detach --name "$fixture_name" --network "$upstream_network" --network-alias remix-api \
  --read-only --cap-drop ALL --security-opt no-new-privileges \
  --mount "type=bind,src=$checkout_dir,dst=/source,readonly" \
  "$guard_image" python /source/scripts/remix-guard-fixture.py --host 0.0.0.0 --port 8080 >/dev/null

start_guard() {
  local creation_args=()
  if [[ "$1" == "enabled" ]]; then creation_args=(--enable-owned-creation); fi
  docker run --detach --name "$guard_name" --network "$frontend_network" --network-alias remix-guard \
    --read-only --init --cap-drop ALL --security-opt no-new-privileges \
    --pids-limit 96 --memory 128m --cpus 0.5 --tmpfs /tmp:size=4m,noexec,nosuid \
    --mount "type=volume,src=$result_volume,dst=/var/lib/remix-guard" "$guard_image" \
    python remix_guard.py --host 0.0.0.0 --port 8081 --upstream http://remix-api:8080 \
    --database /var/lib/remix-guard/terminal.sqlite3 --core-upstream http://core-api:4173 \
    --core-host osgard.world "${creation_args[@]}" >/dev/null
  docker network connect "$upstream_network" "$guard_name"
}
start_guard enabled
sed 's/__OSGARD_HOST_GATEWAY__/127.0.0.1/g' nginx.conf > "$candidate_dir/default.conf"
docker run --detach --name "$nginx_name" --network "$frontend_network" \
  --publish 127.0.0.1::80 \
  --mount "type=bind,src=$checkout_dir/dist,dst=/usr/share/nginx/html,readonly" \
  --mount "type=bind,src=$candidate_dir/default.conf,dst=/etc/nginx/conf.d/default.conf,readonly" \
  nginx:1.27-alpine >/dev/null
candidate_port="$(docker inspect --format '{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' "$nginx_name")"
candidate_base="http://127.0.0.1:$candidate_port"
wait_ready() {
  for _ in $(seq 1 25); do
    if curl --max-time 8 --silent --fail -H 'Host: osgard.world' "$candidate_base/api/remix/health" | grep -q 'osgard-remix-guard' \
      && curl --max-time 8 --silent --fail -H 'Host: osgard.world' "$candidate_base/api/core/health" >/dev/null; then return; fi
    sleep 1
  done
  docker logs "$guard_name" >&2
  docker logs "$core_name" >&2
  return 1
}
wait_ready
docker exec "$nginx_name" nginx -t
python3 scripts/remix-owned-gateway-smoke.py "$candidate_base" active "$candidate_dir/private-fixture.json"
docker exec "$fixture_name" python -c \
  "import urllib.request; urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:8080/__fixture/owned-terminal',data=b'{}',headers={'Content-Type':'application/json'}),timeout=4).read()"
python3 scripts/remix-owned-gateway-smoke.py "$candidate_base" finalized "$candidate_dir/private-fixture.json"

# An ACL-aware rollback has creation off, but must enforce schema-2 ownership.
docker rm -f "$guard_name" >/dev/null
start_guard disabled
wait_ready
python3 scripts/remix-owned-gateway-smoke.py "$candidate_base" restored "$candidate_dir/private-fixture.json"
docker stop "$fixture_name" >/dev/null
python3 scripts/remix-owned-gateway-smoke.py "$candidate_base" legacy-offline "$candidate_dir/private-fixture.json"
docker start "$fixture_name" >/dev/null
wait_ready
docker stop "$core_name" >/dev/null
python3 scripts/remix-owned-gateway-smoke.py "$candidate_base" core-offline "$candidate_dir/private-fixture.json"
echo 'PASS actual Core sessions, protected aliases, one creation, sequence reservation, durable protected cache, disabled-creation rollback and separate service outages.'
