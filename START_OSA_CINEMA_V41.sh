#!/bin/sh
# OSA CINEMA V41 - redesigned local-only owner UI with unchanged V40 security gates.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
[ -r "$ROOT/scripts/osa-cinema-v41-owner-ui.mjs" ] || {
  echo 'OSA CINEMA V41 UI is missing; refusing partial installation' >&2
  exit 1
}
[ -r "$ROOT/scripts/osa-cinema-v39-owner-desk.mjs" ] || {
  echo 'OSA CINEMA owner desk is missing; refusing partial installation' >&2
  exit 1
}
exec sh "$ROOT/START_OSA_CINEMA_V40.sh"
