#!/usr/bin/env bash
set -euo pipefail

container_name="${OSGARD_CONTAINER:-osgard-world}"
archive="${OSGARD_ARCHIVE:-/tmp/osgard-gh-release.tgz}"
core_image="${OSGARD_CORE_IMAGE:-osgard-core-api:release}"
state_file="/tmp/osgard-frontend-activation.state"
log_file="/tmp/osgard-frontend-activation.log"
core_previous="osgard-core-api-previous-$$"
core_volume="osgard-core-data"
core_network=""
core_replaced=0
core_started=0
api_gateway="$(docker inspect --format '{{range $name, $conf := .NetworkSettings.Networks}}{{println $conf.Gateway}}{{end}}' "$container_name" | awk 'NF { print $1; exit }')"
if [[ -z "$api_gateway" ]]; then
  echo "Unable to determine the Docker gateway for $container_name" >&2
  exit 1
fi
echo "Detected host API gateway: $api_gateway"
rm -f "$state_file" "$log_file"
: > "$log_file"

rollback() {
  if [[ "$core_started" == "1" ]]; then
    docker rm -f osgard-core-api >/dev/null 2>&1 || true
  fi
  if [[ "$core_replaced" == "1" ]]; then
    if docker inspect "$core_previous" >/dev/null 2>&1; then
      docker rename "$core_previous" osgard-core-api
      docker start osgard-core-api >/dev/null
    fi
  fi
  docker exec "$container_name" sh -lc '
    set -eu
    if [ -f /tmp/osgard-nginx-previous.conf ]; then
      cp /tmp/osgard-nginx-previous.conf /etc/nginx/conf.d/default.conf
    fi
    if [ -d /tmp/osgard-gh-previous ]; then
      rm -rf /usr/share/nginx/html
      mv /tmp/osgard-gh-previous /usr/share/nginx/html
    fi
    nginx -t && nginx -s reload
  '
}

(
  set -euo pipefail
  trap 'status=$?; printf "Activation worker failed at line %s (exit %s)\n" "$LINENO" "$status" >&2' ERR
  echo 'Activation worker started.'
  docker exec "$container_name" sh -lc "
    set -eux
    rm -rf /tmp/osgard-gh-next /tmp/osgard-gh-previous
    mkdir -p /tmp/osgard-gh-next
    tar -xzf '$archive' -C /tmp/osgard-gh-next
    test -f /tmp/osgard-gh-next/html/index.html
    grep -q '<title>OSGARD WORLD — цифровые продукты, построенные как системы</title>' /tmp/osgard-gh-next/html/index.html
    grep -q 'osgard-app.*osgard-ecosystem' /tmp/osgard-gh-next/html/index.html
    grep -q 'OSGARD WORLD' /tmp/osgard-gh-next/html/assets/*.js
    test -f /tmp/osgard-gh-next/html/skillcred/index.html
    test -f /tmp/osgard-gh-next/html/skillcred/styles.css
    test -f /tmp/osgard-gh-next/html/skillcred/app.js
    echo 'Compressed SkillCred assets in candidate release:'
    ls -l /tmp/osgard-gh-next/html/skillcred/styles.css /tmp/osgard-gh-next/html/skillcred/styles.css.gz /tmp/osgard-gh-next/html/skillcred/app.js /tmp/osgard-gh-next/html/skillcred/app.js.gz
    test -s /tmp/osgard-gh-next/html/skillcred/styles.css.gz
    test -s /tmp/osgard-gh-next/html/skillcred/app.js.gz
    test -f /tmp/osgard-gh-next/nginx.conf
    sed -i 's/__OSGARD_HOST_GATEWAY__/'"$api_gateway"'/g' /tmp/osgard-gh-next/nginx.conf
    if grep -q '__OSGARD_HOST_GATEWAY__' /tmp/osgard-gh-next/nginx.conf; then
      echo 'Unresolved OSGARD host-gateway placeholder in Nginx configuration' >&2
      exit 1
    fi
  "

  image_archive="/tmp/osgard-core-image-$$.tar.gz"
  echo 'Loading the packaged OSGARD Core image.'
  docker cp "$container_name:/tmp/osgard-gh-next/core-api-image.tar.gz" "$image_archive"
  gzip -dc "$image_archive" | docker load
  rm -f "$image_archive"
  mapfile -t frontend_networks < <(docker inspect --format '{{range $name, $conf := .NetworkSettings.Networks}}{{println $name}}{{end}}' "$container_name")
  for network in "${frontend_networks[@]}"; do
    if [[ -n "$network" && "$network" != "bridge" ]]; then
      core_network="$network"
      break
    fi
  done
  if [[ -z "$core_network" ]]; then
    core_network="osgard-core-internal"
    if ! docker network inspect "$core_network" >/dev/null 2>&1; then
      docker network create "$core_network" >/dev/null
    fi
    if ! docker network inspect "$core_network" --format '{{range .Containers}}{{println .Name}}{{end}}' | grep -Fx "$container_name" >/dev/null; then
      docker network connect "$core_network" "$container_name"
    fi
  fi
  if docker inspect osgard-core-api >/dev/null 2>&1; then
    old_volume="$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/var/lib/osgard-core"}}{{if eq .Type "volume"}}{{.Name}}{{end}}{{end}}{{end}}' osgard-core-api)"
    if [[ -n "$old_volume" ]]; then
      core_volume="$old_volume"
    else
      echo 'Existing Core container has no named data volume; refusing an unsafe data migration.' >&2
      exit 1
    fi
    docker stop osgard-core-api >/dev/null
    docker rename osgard-core-api "$core_previous"
    core_replaced=1
  fi
  if [[ "$core_replaced" != "1" ]]; then
    mapfile -t existing_core_volumes < <(docker volume ls -q --filter label=com.docker.compose.volume=osgard-core-data)
    if [[ "${#existing_core_volumes[@]}" -gt 1 ]]; then
      echo 'Multiple OSGARD Core data volumes exist without an active Core container; refusing to choose one automatically.' >&2
      exit 1
    elif [[ "${#existing_core_volumes[@]}" == "1" ]]; then
      core_volume="${existing_core_volumes[0]}"
    elif docker volume inspect osgard-core-data >/dev/null 2>&1; then
      core_volume="osgard-core-data"
    fi
  fi
  if ! docker volume create "$core_volume" >/dev/null; then
    rollback
    exit 1
  fi
  if ! docker run -d --name osgard-core-api --network "$core_network" --network-alias core-api \
    --restart unless-stopped --init --read-only --security-opt no-new-privileges --cap-drop ALL \
    --pids-limit 128 --memory 768m --cpus 1.0 --tmpfs /tmp:size=16m,noexec,nosuid \
    --mount "type=volume,src=$core_volume,dst=/var/lib/osgard-core" \
    -e OSGARD_CORE_PUBLIC_ORIGIN=https://osgard.world "$core_image"; then
    rollback
    exit 1
  fi
  core_started=1
  core_ready=0
  for _ in $(seq 1 30); do
    if docker exec osgard-core-api python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:4173/api/core/health', timeout=3)"; then
      core_ready=1
      break
    fi
    sleep 2
  done
  if [[ "$core_ready" != "1" ]]; then
    echo 'New OSGARD Core API did not become healthy; rolling back.' >&2
    docker logs --tail 100 osgard-core-api >&2 || true
    rollback
    exit 1
  fi

  if ! docker exec "$container_name" sh -lc "
    set -eu
    cp /etc/nginx/conf.d/default.conf /tmp/osgard-nginx-previous.conf
    mv /usr/share/nginx/html /tmp/osgard-gh-previous
    mv /tmp/osgard-gh-next/html /usr/share/nginx/html
    cp /tmp/osgard-gh-next/nginx.conf /etc/nginx/conf.d/default.conf
    echo 'Nginx compression module diagnostics:'
    nginx -V 2>&1 | grep -o 'http_gzip[^ ]*' || true
    if nginx -t; then
      nginx -s reload
    else
      cp /tmp/osgard-nginx-previous.conf /etc/nginx/conf.d/default.conf
      rm -rf /usr/share/nginx/html
      mv /tmp/osgard-gh-previous /usr/share/nginx/html
      nginx -t && nginx -s reload
      exit 1
    fi
  "; then
    rollback
    exit 1
  fi

  set -x
  if curl --max-time 12 --compressed -fsS -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' "https://osgard.world/?osa_deploy_verify=$(date +%s)" -o /tmp/osa-home-check.html \
    && grep -q '<title>OSGARD WORLD — цифровые продукты, построенные как системы</title>' /tmp/osa-home-check.html \
    && grep -q 'name="osgard-app" content="osgard-ecosystem"' /tmp/osa-home-check.html \
    && home_bundle_path="$(grep -oE 'src="[^"]+\.js"' /tmp/osa-home-check.html | head -n 1 | sed 's/^src="//;s/"$//')" \
    && test -n "$home_bundle_path" \
    && curl --max-time 12 --compressed -fsS -H 'Cache-Control: no-cache' "https://osgard.world$home_bundle_path" -o /tmp/osa-home-bundle-check.js \
    && grep -q 'OSGARD WORLD' /tmp/osa-home-bundle-check.js \
    && curl --max-time 12 -fsS https://osgard.world/api/core/health -o /tmp/osgard-core-health-check.json \
    && grep -q '"status":"ok"' /tmp/osgard-core-health-check.json \
    && curl --max-time 12 -fsS https://osgard.world/ >/dev/null \
    && curl --max-time 12 -fsS https://osgard.world/skillcred/ -o /tmp/skillcred-page-check.html \
    && grep -q 'id="issueBtn"' /tmp/skillcred-page-check.html \
    && grep -q 'name="api-base" content="/skillcred-api"' /tmp/skillcred-page-check.html \
    && curl --max-time 12 -sS -D /tmp/skillcred-direct-gzip-headers.txt -o /tmp/skillcred-direct-gzip-body.gz https://osgard.world/skillcred/styles.css.gz \
    && { echo 'Direct .gz URL response:'; grep -Ei '^(HTTP/|content-type:|content-length:|content-encoding:|cache-control:)' /tmp/skillcred-direct-gzip-headers.txt || true; wc -c /tmp/skillcred-direct-gzip-body.gz; } \
    && curl --max-time 12 --compressed -fsS https://osgard.world/skillcred/styles.css -o /tmp/skillcred-css-check.txt \
    && grep -qi -- '--acid:#c8ff3d' /tmp/skillcred-css-check.txt \
    && grep -oE '/skillcred/styles\.css\?v=[A-Za-z0-9]+' /tmp/skillcred-page-check.html > /tmp/skillcred-versioned-css-paths.txt \
    && css_path="$(sed -n '1p' /tmp/skillcred-versioned-css-paths.txt)" \
    && test -n "$css_path" \
    && curl --max-time 12 -fsS -H 'Accept-Encoding: gzip' -D /tmp/skillcred-versioned-css-headers.txt -o /tmp/skillcred-versioned-css.gz "https://osgard.world$css_path" \
    && { if grep -qi '^content-encoding: gzip' /tmp/skillcred-versioned-css-headers.txt; then echo "PASS: CSS served with gzip Content-Encoding"; else echo "WARN: public edge returned uncompressed CSS despite local gzip variants; continuing with valid live site"; cat /tmp/skillcred-versioned-css-headers.txt; fi; } \
    && curl --max-time 12 --compressed -fsS https://osgard.world/skillcred/app.js -o /tmp/skillcred-js-check.txt \
    && grep -q 'demo/issue' /tmp/skillcred-js-check.txt \
    && { if curl --max-time 12 -fsS https://osgard.world/skillcred-api/health -o /tmp/skillcred-health-check.json \
      && grep -q '"version":"0.3.0"' /tmp/skillcred-health-check.json \
      && curl --max-time 12 -fsS https://osgard.world/skillcred-api/ready -o /tmp/skillcred-ready-check.json \
      && grep -q '"ready":true' /tmp/skillcred-ready-check.json; then \
        echo 'PASS: SkillCred external API is healthy'; \
      else \
        echo 'WARN: SkillCred external API is unavailable; keeping the independently verified OSGARD site release active'; \
      fi; } \
    && curl --max-time 10 -fsS http://127.0.0.1:4317/health -o /tmp/osgard-game-health-check.json \
    && grep -q '"status":"ok"' /tmp/osgard-game-health-check.json; then
    printf 'success\n' > "$state_file"
  else
    rollback
    printf 'failed\n' > "$state_file"
    exit 1
  fi
  if [[ -n "$core_previous" ]] && docker inspect "$core_previous" >/dev/null 2>&1; then
    docker rm "$core_previous" >/dev/null
    core_replaced=0
  fi
) >"$log_file" 2>&1 &
pid=$!
for _ in $(seq 1 300); do
  [[ -f "$state_file" ]] && break
  kill -0 "$pid" 2>/dev/null || break
  sleep 1
done
if [[ ! -f "$state_file" ]]; then
  kill "$pid" 2>/dev/null || true
  cat "$log_file" || true
  exit 1
fi
cat "$log_file" || true
grep -q '^success$' "$state_file"
