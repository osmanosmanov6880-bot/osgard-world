#!/bin/sh
# OSA CINEMA V40 - local owner audit. No film, PDF, rights or passwords uploaded.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
command -v node >/dev/null 2>&1 || { echo 'Node.js 22+ required' >&2; exit 1; }
node -e "process.exit(Number(process.versions.node.split('.')[0]) >= 22 ? 0 : 1)" || {
  echo 'Node.js 22+ required' >&2; exit 1;
}
[ -r "$ROOT/scripts/osa-cinema-v40-audit-worker.mjs" ] || {
  echo 'Missing V40 worker: refusing incomplete package' >&2; exit 1;
}
exec sh "$ROOT/START_OSA_CINEMA_V39.sh"
