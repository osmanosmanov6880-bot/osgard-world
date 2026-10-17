# Production Core service

The production Compose stack runs the same self-hosted Core API used by the local pilot. Nginx routes `/api/core/` to the private `core-api` service. The API port is exposed only to the Compose network. SQLite lives in the named `osgard-core-data` volume, and the container runs as an unprivileged user with a read-only root filesystem, dropped Linux capabilities, bounded memory/CPU and a health check.

## Build and start

Build the frontend first, then build the production stack from the project root:

```sh
npm ci
npm run build
docker compose -f docker-compose.production.yml config
docker compose -f docker-compose.production.yml up -d --build
docker compose -f docker-compose.production.yml ps
```

The existing host reverse proxy must terminate HTTPS and forward `osgard.world` to `127.0.0.1:4189`. The default Core origin is `https://osgard.world`; set `OSGARD_CORE_PUBLIC_ORIGIN` only when the canonical public origin differs. Keep the Core service port private. Do not route the API around Nginx or expose port 4173 on the host.

Check the public gateway after HTTPS and the reverse proxy are configured:

```sh
curl --fail --silent --show-error https://osgard.world/api/core/health
```

The health response reports the API/schema state only. It does not prove a backup, recovery, browser session, or full service-level objective.

## Backups and restore

Create a consistent SQLite snapshot while the service is running:

```sh
bash scripts/backup-core-production.sh
```

The script uses the shared SQLite online backup API, checks `integrity_check`, `foreign_key_check` and the Core schema, and writes three private files under `./backups/core` (or `OSGARD_CORE_BACKUP_DIR`): the SQLite snapshot, a `.sha256` checksum and a `.manifest.json` binding the file name, size, digest and schema. Store copies outside the production host as well; a named Docker volume is persistence, not a backup. Schedule the script with the host's approved scheduler and periodically restore a copy into a new isolated directory/server before depending on it.

Before a schema or image upgrade, create and verify a backup. Keep `osgard-core-data` attached to the service. Never replace a live database file manually. If recovery is needed, stop the service and restore into the volume only after validating the snapshot on a separate copy and documenting the recovery point.

The provided restore command performs only the separate offline validation stage; it refuses the production volume and never starts a service or switches traffic:

```sh
python3 scripts/restore-core-backup.py /private/backups/SNAPSHOT.sqlite3 \
  --manifest /private/backups/SNAPSHOT.sqlite3.manifest.json \
  --target-dir /private/recovery-exercises/new-run \
  --sha256 INDEPENDENTLY_RECORDED_64_HEX_DIGEST
```

The target parent must already exist and `new-run` must not. For nonstandard production data locations, add `--protected-root /your/live/volume`. See [CORE-RECOVERY-DRILL.md](CORE-RECOVERY-DRILL.md) for metadata validation, existing-backup admission, the complete local HTTP exercise and report limits.

## Limits before public launch

This wiring makes the code reachable through the production stack; it does not complete production acceptance. Before relying on real users, configure and verify the host TLS/reverse-proxy trust chain and client-IP rate limits, test a full backup/restore on the target host, add external uptime and disk/volume alerts, review data retention and privacy requirements, and complete real browser/mobile and accessibility checks. No SSO, email recovery, AI provider, marketplace, payment integration, or payment processing is included.

## Безопасность резервирования — усиленный сценарий

`backup-core-production.sh` использует уникальное имя снимка по UTC и PID, приватный pending-файл на хосте и trap для очистки после обычных ошибок. В контейнере временный snapshot создаётся на `/var/lib/osgard-core/.osgard-core-backup-…sqlite3`, отдельно от рабочей базы. Это сохраняет возможность резервирования базы больше 16 MiB: контейнерный `/tmp` ограничен tmpfs такого размера. Нужен запас места на data volume и на backup-хосте; текущий предел snapshot — 1 GiB, SQL/online-copy — 30 секунд, Docker exec/cp — по 120 секунд.

Источник открывается только как существующая база (`mode=ro`); missing source не превращается в пустую «успешную» копию. SHA-256, полученный в контейнере, сверяется с реально перенесёнными байтами до публикации. Manifest пишется последним. Существующие DB/manifest/checksum и sidecar не перезаписываются. Все компоненты пути проверяются на симлинки; уже существующий backup-каталог должен иметь права `0700`, а не автоматически менять права общего или системного каталога. Деревья `public`, `dist`, `PAGES` для SQLite backup запрещены.

Перед включением расписания отдельно выполните практический тест на целевом Docker-хосте. CI выполняет shell-команду через эмуляцию Docker transport с настоящим CoreStore/backup/publish и отдельно проводит полный HTTP recovery на новых локальных данных. Эти проверки не запускают production Docker и не восстанавливают production backup. Файл или health-check сами по себе не заменяют проверку восстановленных бизнес-связей; для конкретной реальной копии выполните изолированное испытание и задокументируйте её recovery point.
