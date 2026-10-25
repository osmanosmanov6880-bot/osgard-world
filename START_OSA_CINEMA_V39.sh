#!/bin/sh
# OSA CINEMA V39 - private workstation only. Avoid passwords in shell history.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
command -v node >/dev/null 2>&1 || { echo 'Node.js 22+ required' >&2; exit 1; }
[ -r /dev/tty ] || { echo 'Run in an interactive terminal' >&2; exit 1; }
printf 'OSA CINEMA V39 - private only; film and payments remain NO-GO\n' > /dev/tty
printf 'Absolute V29 receipt folder: ' > /dev/tty
IFS= read -r RECEIPTS < /dev/tty
printf 'Absolute private MP4 folder: ' > /dev/tty
IFS= read -r MASTERS < /dev/tty
printf 'Absolute private WebVTT folder: ' > /dev/tty
IFS= read -r CAPTIONS < /dev/tty
printf 'Owner password (hidden): ' > /dev/tty
stty -echo < /dev/tty
trap 'stty echo < /dev/tty; unset OSA_CINEMA_OWNER_PASSWORD' EXIT HUP INT TERM
IFS= read -r OSA_CINEMA_OWNER_PASSWORD < /dev/tty
stty echo < /dev/tty
printf '\n' > /dev/tty
export OSA_CINEMA_OWNER_PASSWORD
node "$ROOT/scripts/osa-cinema-v39-owner-desk.mjs" --repo-root "$ROOT" --receipts-dir "$RECEIPTS" --masters-dir "$MASTERS" --captions-dir "$CAPTIONS"
