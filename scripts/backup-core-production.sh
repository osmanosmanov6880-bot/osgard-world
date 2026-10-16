#!/usr/bin/env bash
set -euo pipefail
umask 077

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

compose_file="${OSGARD_COMPOSE_FILE:-docker-compose.production.yml}"
backup_dir="${OSGARD_CORE_BACKUP_DIR:-./backups/core}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
name="osgard-core-${timestamp}.sqlite3"
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"

docker compose -f "$compose_file" exec -T core-api python -c \
  'import os,sqlite3; src=sqlite3.connect("/var/lib/osgard-core/core.sqlite3"); dst=sqlite3.connect("/tmp/osgard-core-backup.sqlite3"); src.backup(dst); dst.close(); src.close(); check=sqlite3.connect("/tmp/osgard-core-backup.sqlite3"); result=check.execute("PRAGMA integrity_check").fetchone()[0]; check.close(); assert result=="ok", result; os.chmod("/tmp/osgard-core-backup.sqlite3",0o600)' \
  && docker compose -f "$compose_file" cp core-api:/tmp/osgard-core-backup.sqlite3 "$backup_dir/$name"

docker compose -f "$compose_file" exec -T core-api rm -f /tmp/osgard-core-backup.sqlite3
chmod 600 "$backup_dir/$name"
sha256sum "$backup_dir/$name" > "$backup_dir/$name.sha256"
chmod 600 "$backup_dir/$name.sha256"
sha256sum -c "$backup_dir/$name.sha256"
printf 'Consistent Core database backup created: %s\n' "$backup_dir/$name"
