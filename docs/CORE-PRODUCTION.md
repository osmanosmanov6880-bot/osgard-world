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

The script uses SQLite's online backup API, runs `integrity_check`, writes a private file under `./backups/core` (or `OSGARD_CORE_BACKUP_DIR`), and records a SHA-256 checksum. Store copies outside the production host as well; a named Docker volume is persistence, not a backup. Schedule the script with the host's approved scheduler and periodically restore a copy to a separate test file/server before depending on it.

Before a schema or image upgrade, create and verify a backup. Keep `osgard-core-data` attached to the service. Never replace a live database file manually. If recovery is needed, stop the service and restore into the volume only after validating the snapshot on a separate copy and documenting the recovery point.

## Limits before public launch

This wiring makes the code reachable through the production stack; it does not complete production acceptance. Before relying on real users, configure and verify the host TLS/reverse-proxy trust chain and client-IP rate limits, test a full backup/restore on the target host, add external uptime and disk/volume alerts, review data retention and privacy requirements, and complete real browser/mobile and accessibility checks. No SSO, email recovery, AI provider, marketplace, payment integration, or payment processing is included.
