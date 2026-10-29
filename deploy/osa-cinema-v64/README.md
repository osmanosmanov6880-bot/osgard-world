# OSA CINEMA V64 — self-hosted deployment references (NOT deployed)

These files are **examples**, not evidence of a live commercial SaaS service.
Before using them, replace `cinema.example.com` in both Caddy and systemd.
The expected project location is `/srv/osgard-world`; the private SQLite
database is at `/var/lib/osgard-cinema/core.sqlite3`, never inside `dist`.

## Controlled rollout

1. Run all V64 and previous Core/OSA CI. Ensure the actual Git commit was
   reviewed. Provision a dedicated non-root `osgard` OS account, private data
   directories, least-privilege firewall, an encrypted volume and HTTPS domain.
2. Deploy `dist` and source on a server you control. Do not make the SQLite
   path, exported snapshot or user file bytes web-accessible.
3. Configure Caddy with the real domain; confirm reverse-proxy Host/Origin
   headers and valid HTTPS. Never expose Python port 4173 to the internet.
4. Review the systemd service and backup examples. Copy them into the
   appropriate system directories only after operator review; the example
   backup timer is **not automatically enabled** by this Git commit.
5. Back up before deployment and after every schema change. Use
   `python3 scripts/osa-cinema-v64-recovery-drill.py --source ... --target ... --public-root dist`
   and confirm `status=PASS`. This is a **test of a consistent snapshot**,
   not a restoration into a running production service.
6. Implement independent encrypted offsite backups, disaster-recovery
   testing on isolated hardware, incident response, telemetry, a persistent
   delivery queue, alerts, key management, antivirus scanning, and data
   retention policies before the system handles sensitive real users.
7. The V64 `GET /api/core/cinema/spaces/{id}/vault/integrity` checks SQLite
   file contents against server-stored SHA-256 **only for the workspace owner**.
   It does not validate source authenticity, malware, rights or provenance.

## The hard NO-GO list

**File BLOBs and backup snapshots are not encrypted at the application layer.**
HTTPS transport does not protect unencrypted disk backups. The sample
`backup-once.sh` generates a restricted snapshot locally but does not
encrypt or transfer it. Do not enable that timer without an approved,
encrypted storage and retention process.

The application still lacks managed object storage, reliable global failover,
isolated availability zones, professional rights clearance and high-volume
media delivery. `ZERO WINDOW` has 0/13 independently verified filmed scenes.
Storing a private MP4 proxy is not publishing a film.

Production readiness is **false** in the V64 storage overview and integrity
report. No external deployment is performed by this release.
