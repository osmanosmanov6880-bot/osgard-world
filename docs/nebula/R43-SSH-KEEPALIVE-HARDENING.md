# NEBULA long-lived SSH release hardening — 2026-11-04

Production R43 has already been activated and independently verified under release #41851783164, public parity #41852899805. This operations change is **not a new gameplay release**.

## Incident evidence

- First R43 isolated SSH deployment attempt ended `Connection closed by <redacted host> port 22`, exit 255, without a successful completion marker.
- The previous public R42 asset identities still matched after the failed attempt.
- Re-running only the failed deployment job succeeded; public R43 assets subsequently matched the allowlist 4/4.
- Root cause of the first SSH connection closure is **not known** from the available GitHub logs. It could be idle network behavior, resource pressure or a remote process/network interruption. Do not claim proven causality.

## Mitigation (PR only until validated)

For the three existing SSH-family commands (mkdir via SSH, archive transfer via SCP, remote activation via SSH), add:

- `BatchMode=yes` — do not hang awaiting interactive credentials.
- `ServerAliveInterval=15` — encrypted SSH heartbeat every 15 seconds of inactivity.
- `ServerAliveCountMax=12` — abort if the server repeatedly fails to respond.
- `ConnectTimeout=20` — bound connection establishment latency.

No change to code signatures, approved artifact hashes, host key behavior, Nginx routes, staging disk checks, release locking, rollback logic or paid entitlements. **Do not add automatic SSH activation retries**: a retry of an unknown, partially applied remote script could cause concurrent releases. A rerun remains an explicit operator decision after checking published asset identity.

## Required review

- [ ] Workflow YAML syntax and existing negative asset-guard tests pass.
- [ ] Verify remote host accepts standard OpenSSH keepalive options (normal OpenSSH 9.x supports them).
- [ ] Avoid merging during another production activation. Updating the deployment workflow triggers the existing isolated release job by design.
- [ ] Preserve the last known good version if a later deployment fails.
