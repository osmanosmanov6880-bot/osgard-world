#!/usr/bin/env bash
set -euo pipefail
umask 077

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

compose_file="${OSGARD_COMPOSE_FILE:-docker-compose.production.yml}"
backup_dir="${OSGARD_CORE_BACKUP_DIR:-./backups/core}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
name="osgard-core-${timestamp}-$$.sqlite3"
remote_tmp="/tmp/osgard-core-backup-${timestamp}-$$.sqlite3"

if [[ -L "$backup_dir" ]]; then
  echo "Refusing symlink backup directory" >&2
  exit 1
fi
mkdir -p -- "$backup_dir"
chmod 700 -- "$backup_dir"
final="$backup_dir/$name"
if [[ -e "$final" || -L "$final" ]]; then
  echo "Refusing to replace existing Core backup: $final" >&2
  exit 1
fi
pending="$(mktemp "$backup_dir/.osgard-core-pending-XXXXXXXX")"
completed=0
cleanup() {
  docker compose -f "$compose_file" exec -T core-api rm -f -- "$remote_tmp" >/dev/null 2>&1 || true
  rm -f -- "$pending"
  if [[ "$completed" != 1 ]]; then
    rm -f -- "$final" "$final.sha256"
  fi
}
trap cleanup EXIT

docker compose -f "$compose_file" exec -T core-api python -c \
  'import os,sqlite3,sys; dstpath=sys.argv[1]; src=sqlite3.connect("/var/lib/osgard-core/core.sqlite3"); dst=sqlite3.connect(dstpath); src.backup(dst); dst.close(); src.close(); check=sqlite3.connect(dstpath); result=check.execute("PRAGMA integrity_check").fetchone()[0]; check.close(); assert result=="ok", result; os.chmod(dstpath,0o600)' \
  "$remote_tmp"

docker compose -f "$compose_file" cp "core-api:$remote_tmp" "$pending"
chmod 600 -- "$pending"
mv -n -- "$pending" "$final"
if [[ ! -f "$final" ]]; then
  echo "Core backup was not moved into final location" >&2
  exit 1
fi
sha256sum "$final" > "$final.sha256"
chmod 600 -- "$final.sha256"
sha256sum -c "$final.sha256"
completed=1
printf 'Consistent Core database backup created: %s\n' "$final"
