#!/usr/bin/env bash
set -euo pipefail
umask 077

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

compose_file="${OSGARD_COMPOSE_FILE:-docker-compose.production.yml}"
backup_dir="${OSGARD_CORE_BACKUP_DIR:-./backups/core}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
name="osgard-core-${timestamp}-$$.sqlite3"
# The container's /tmp is a 16 MiB tmpfs. Reserve the online snapshot on the
# writable data volume instead; this never replaces the live core.sqlite3 file.
remote_tmp="/var/lib/osgard-core/.osgard-core-backup-${timestamp}-$$.sqlite3"

if [[ -L "$backup_dir" ]]; then
  echo "Refusing symlink backup directory" >&2
  exit 1
fi
python3 - "$backup_dir" <<'PY'
import stat, sys
sys.path.insert(0, 'server')
from core_backup import prepare_directory
directory = prepare_directory(sys.argv[1])
if stat.S_IMODE(directory.stat().st_mode) & 0o077:
    raise ValueError('Backup directory must already be private (mode 0700); do not reuse a shared/system directory.')
PY
final="$backup_dir/$name"
if [[ -e "$final" || -L "$final" ]]; then
  echo "Refusing to replace existing Core backup: $final" >&2
  exit 1
fi
pending="$(mktemp "$backup_dir/.osgard-core-pending-XXXXXXXX")"
cleanup() {
  timeout 10s docker compose -f "$compose_file" exec -T core-api rm -f -- \
    "$remote_tmp" "$remote_tmp-wal" "$remote_tmp-shm" "$remote_tmp-journal" >/dev/null 2>&1 || true
  rm -f -- "$pending"
}
trap cleanup EXIT

remote_sha="$(timeout 120s docker compose -f "$compose_file" exec -T core-api python -c \
  'import sys; from core_backup import backup; print(backup("/var/lib/osgard-core/core.sqlite3", sys.argv[1]))' \
  "$remote_tmp")"
if [[ ! "$remote_sha" =~ ^[0-9a-f]{64}$ ]]; then
  echo "Core container did not return a valid snapshot SHA-256" >&2
  exit 1
fi

timeout 120s docker compose -f "$compose_file" cp "core-api:$remote_tmp" "$pending"
chmod 600 -- "$pending"
# Validate the transferred bytes against the digest returned by the container.
# The shared publisher checks the Core schema, SQLite integrity and foreign keys,
# refuses all existing DB/manifest/checksum paths, and publishes the manifest last.
python3 server/core_backup.py publish "$pending" "$final" --sha256 "$remote_sha" \
  --method sqlite-online-backup --json
sha256sum -c "$final.sha256"
printf 'Consistent Core database backup created: %s\n' "$final"
