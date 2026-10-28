#!/usr/bin/env bash
# CITY REIGN source-native standalone PUBLIC TECHNICAL PREVIEW for OSGARD.
# This script operates on ONE isolated directory in the EXISTING Nginx
# container. The flagship /games/omega-3d-preview/ and all other products
# are NEVER moved, rewritten, deleted or restarted by this script.
set -euo pipefail

action="${1:-}"
run_id="${2:-}"
source_sha="${3:-}"
case "$action" in
  activate|rollback|finalize) ;;
  *) echo "Unsupported CITY REIGN preview action" >&2; exit 2 ;;
esac
if ! [[ "$run_id" =~ ^[0-9]{6,20}$ ]] || ! [[ "$source_sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Invalid exact-run/source identifiers" >&2
  exit 2
fi

container="osgard-world"
transport="/tmp/osgard-city-reign-preview-${run_id}"
game_root="/usr/share/nginx/html/games"
target="${game_root}/city-reign-preview"
candidate="${game_root}/.city-reign-preview-candidate-${run_id}"
previous="${game_root}/.city-reign-preview-backup-${run_id}"
failed="${game_root}/.city-reign-preview-failed-${run_id}"
lock="/run/lock/osgard-frontend-activation.lock"

# Serialize against the EXISTING full-website Nginx root swap and existing
# independent Omega SSH release. A failed lock fails without changing live.
if [ -L "$lock" ] || ! command -v flock >/dev/null 2>&1; then
  echo "Trusted shared OSGARD activation lock unavailable" >&2
  exit 3
fi
exec 9>>"$lock"
if ! flock -w 120 9; then
  echo "OSGARD Nginx full-site activation is busy" >&2
  exit 3
fi
if ! docker inspect "$container" >/dev/null 2>&1; then
  echo "Existing OSGARD Nginx container unavailable" >&2
  exit 3
fi

if [ "$action" = "activate" ]; then
  test -d "$transport" && test ! -L "$transport"
  test -s "$transport/release.tgz"
  test ! -e "$transport/unpacked"
  # Reject symlinks, absolute paths, parent traversals, unexpected files
  # and tar bombs even if an archive were substituted after CI attestation.
  python3 - "$transport/release.tgz" <<'PY'
import sys,tarfile
from pathlib import PurePosixPath
allowed={
    "index.html","index.js","index.wasm","index.pck","index.png",
    "index.audio.worklet.js","index.audio.position.worklet.js",
    "release.json","SHA256SUMS.txt"
}
size=0
with tarfile.open(sys.argv[1],"r:gz") as archive:
    members=archive.getmembers()
    if not 6 <= len(members) <= 16:
        raise SystemExit("Unexpected number of native Godot release entries")
    names=set()
    for m in members:
        path=PurePosixPath(m.name)
        name=str(path)
        if m.isdir() and name==".":
            continue
        if not m.isfile() or path.is_absolute() or ".." in path.parts:
            raise SystemExit("Refusing unsafe release archive member")
        if name not in allowed or name in names or m.size<=0 or m.size>110_000_000:
            raise SystemExit("Refusing unexpected/duplicate/oversized native game file")
        names.add(name)
        size+=m.size
    if not {"index.html","index.js","index.wasm","index.pck",
            "release.json","SHA256SUMS.txt"} <= names or size>140_000_000:
        raise SystemExit("Native game archive incomplete/oversized")
PY
  mkdir -p "$transport/unpacked"
  tar -xzf "$transport/release.tgz" -C "$transport/unpacked"
  (
    cd "$transport/unpacked"
    sha256sum -c SHA256SUMS.txt
  )
  python3 - "$transport/unpacked" "$source_sha" <<'PY'
import json,sys
from pathlib import Path
root=Path(sys.argv[1])
expected=sys.argv[2]
m=json.loads((root/"release.json").read_text(encoding="utf-8"))
if not (
    m.get("source_commit")==expected
    and m.get("source_path")=="godot/empire-omega"
    and m.get("engine")=="Godot 4.4.1"
    and m.get("native_tests")=="passed"
    and m.get("artifact_kind")=="native-Godot-HTML5-export"
    and m.get("main_scene")=="res://scenes/main.tscn"
    and m.get("channel")=="public-technical-preview"
    and m.get("commercial_aaa_release") is False
    and m.get("relative_url")=="/games/city-reign-preview/"
):
    raise SystemExit("Invalid CITY REIGN exact-source preview manifest")
for name in ("index.html","index.js","index.wasm","index.pck"):
    if not (root/name).is_file():
        raise SystemExit("Missing original WebGL source file: "+name)
assert (root/"index.wasm").open("rb").read(4)==bytes.fromhex("0061736d")
assert (root/"index.pck").open("rb").read(4)==b"GDPC"
print("PASS: authentic CITY REIGN Godot export locked to source",expected)
PY
  # A leftover target/candidate for the SAME run is never clobbered.
  docker exec -i "$container" sh -s -- "$candidate" "$previous" "$failed" <<'CONTAINER'
set -eu
candidate="$1"; previous="$2"; failed="$3"
test ! -e "$candidate" && test ! -e "$previous" && test ! -e "$failed"
mkdir -p "$(dirname "$candidate")" "$candidate"
CONTAINER
  docker cp "$transport/unpacked/." "$container:$candidate/"
  docker exec -i "$container" sh -s -- "$candidate" "$source_sha" <<'CONTAINER'
set -eu
candidate="$1"; source_sha="$2"
cd "$candidate"
sha256sum -c SHA256SUMS.txt
test -s index.html && test -s index.js && test -s index.wasm && test -s index.pck
grep -Fq "$source_sha" release.json
CONTAINER
  # One-directory atomic rename and immediate in-container re-hash.
  # On ANY local activation failure, move the old preview back.
  docker exec -i "$container" sh -s -- "$candidate" "$target" "$previous" <<'CONTAINER'
set -eu
candidate="$1"; target="$2"; previous="$3"
test -d "$candidate" && test ! -L "$candidate"
if [ -e "$target" ]; then
  test -d "$target" && test ! -L "$target"
  test -s "$target/SHA256SUMS.txt"
  (cd "$target" && sha256sum -c SHA256SUMS.txt >/dev/null)
  test ! -e "$previous"
  mv "$target" "$previous"
fi
if ! mv "$candidate" "$target"; then
  if [ -e "$previous" ]; then mv "$previous" "$target"; fi
  exit 1
fi
if ! (cd "$target" && sha256sum -c SHA256SUMS.txt >/dev/null); then
  mv "$target" "${candidate}.invalid"
  if [ -e "$previous" ]; then mv "$previous" "$target"; fi
  exit 1
fi
echo "CITY_REIGN_PREVIEW_ACTIVATED: exact-source isolated Godot route"
CONTAINER
  echo "CITY REIGN PREVIEW: new isolated route activated, AWAITING public HTTPS byte-level attestation"
elif [ "$action" = "rollback" ]; then
  # Caller may rollback ONLY the same run's release. Do not allow an older
  # CI runner to overwrite a later public preview deployed after this run.
  docker exec -i "$container" sh -s -- "$target" "$previous" "$failed" "$source_sha" <<'CONTAINER'
set -eu
target="$1"; previous="$2"; failed="$3"; source_sha="$4"
test -d "$target" && test -s "$target/release.json"
grep -Fq "$source_sha" "$target/release.json"
test ! -e "$failed"
mv "$target" "$failed"
if [ -e "$previous" ]; then
  test -d "$previous" && test -s "$previous/SHA256SUMS.txt"
  if ! mv "$previous" "$target"; then
    mv "$failed" "$target"
    exit 1
  fi
  if ! (cd "$target" && sha256sum -c SHA256SUMS.txt >/dev/null); then
    echo "Previous CITY REIGN preview backup failed integrity check" >&2
    exit 1
  fi
fi
echo "CITY_REIGN_PREVIEW_ROLLBACK: only requested isolated release reverted"
CONTAINER
elif [ "$action" = "finalize" ]; then
  docker exec -i "$container" sh -s -- "$target" "$source_sha" <<'CONTAINER'
set -eu
target="$1"; source_sha="$2"
test -d "$target" && test -s "$target/release.json"
grep -Fq "$source_sha" "$target/release.json"
(cd "$target" && sha256sum -c SHA256SUMS.txt >/dev/null)
echo "CITY_REIGN_PREVIEW_FINALIZED: live native files still SHA-attested"
CONTAINER
  # Remove ONLY our authenticated transfer directory. Keep the previous
  # release backup for a controlled rollback; never prune Docker or site.
  if [ ! -L "$transport" ] && [ -d "$transport" ] &&
     [ -s "$transport/release.tgz" ]; then
    rm -rf -- "$transport"
  fi
fi
