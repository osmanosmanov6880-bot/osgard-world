#!/usr/bin/env bash
# NEBULA CI: download only the two exact official Godot 4.7.2 assets.
# Upstream GitHub CDN sometimes returns 504. Retry official release paths
# and accept only binaries with the published GitHub release SHA-256 digests.
set -euo pipefail

DEST="/tmp/nebula-godot"
VERSION="4.7.2-stable"
RELEASE="https://github.com/godotengine/godot-builds/releases/download/$VERSION"
API="https://api.github.com/repos/godotengine/godot-builds/releases/assets"
mkdir -p "$DEST"

fetch_verified() {
  local filename="$1" slug="$2" asset_id="$3" expected_size="$4" sha="$5"
  local current="$DEST/$filename" temp="$DEST/.download-$filename"
  local direct="$RELEASE/$slug" api="$API/$asset_id"
  if [ -s "$current" ] &&
       printf '%s  %s\n' "$sha" "$current" | sha256sum --check --status; then
    echo "OFFICIAL_GODOT_VERIFIED cached $filename"
    return 0
  fi

  for origin in direct official_api; do
    rm -f -- "$temp"
    local url="$direct"
    if [ "$origin" = official_api ]; then
      url="$api"
      # The fallback is the REST release-asset endpoint of the SAME
      # godotengine/godot-builds asset. It is not an unknown third-party mirror.
      if [ -z "${GITHUB_TOKEN:-}" ]; then
        echo "::warning::GitHub token absent; skip official release API fallback"
        continue
      fi
    fi
    echo "OFFICIAL_GODOT_FETCH $filename origin=$origin"
    local ok=0
    if [ "$origin" = official_api ]; then
      curl -fSL --retry 4 --retry-all-errors --retry-delay 5 \
        --connect-timeout 20 --max-time 1000 \
        -H "Accept: application/octet-stream" \
        -H "Authorization: Bearer $GITHUB_TOKEN" "$url" -o "$temp" && ok=1
    else
      curl -fSL --retry 4 --retry-all-errors --retry-delay 5 \
        --connect-timeout 20 --max-time 1000 \
        "$url" -o "$temp" && ok=1
    fi
    if [ "$ok" -ne 1 ]; then
      echo "::warning::Official $origin endpoint unreachable for $filename"
      continue
    fi
    if [ "$(stat -c%s "$temp")" -ne "$expected_size" ]; then
      echo "::warning::Official $origin size mismatch for $filename"
      continue
    fi
    if ! printf '%s  %s\n' "$sha" "$temp" | sha256sum --check --status; then
      echo "::warning::Official $origin SHA-256 mismatch for $filename"
      continue
    fi
    mv -f -- "$temp" "$current"
    echo "OFFICIAL_GODOT_VERIFIED $filename sha256=$sha"
    return 0
  done

  rm -f -- "$temp"
  echo "::error::OFFICIAL_GODOT_UNAVAILABLE_OR_BAD_DIGEST $filename"
  return 1
}

# Published asset digests and sizes from the official public GitHub release.
fetch_verified "engine.zip" "Godot_v4.7.2-stable_linux.x86_64.zip" \
  "519677358" "77860424" \
  "cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4"
fetch_verified "templates.tpz" "Godot_v4.7.2-stable_export_templates.tpz" \
  "519674520" "1281349702" \
  "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011"
