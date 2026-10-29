#!/bin/sh
# Sample operator-run backup. Requires a private, access-restricted backup directory.
# Not an encrypted or remotely replicated backup.
set -eu
umask 077
SOURCE="/var/lib/osgard-cinema/core.sqlite3"
DEST_DIR="/var/backups/osgard-cinema"
mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="$DEST_DIR/core-$STAMP.sqlite3"
python3 /srv/osgard-world/scripts/osa-cinema-v64-recovery-drill.py \
  --source "$SOURCE" --target "$DEST" --public-root /srv/osgard-world/dist
