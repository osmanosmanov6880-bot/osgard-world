# Core REMIX arena — current-master integration (review only)

Base: `8ae58c55a56c52dfd11d664282a577704bba0a87`. Source: historical validated `bee36cf277c02bced5409fe85bed66e5cd8ba1e1`, PR #128.
This candidate **does not merge PR #128** or alter production configuration.

## Isolation contract

The authoritative `/api/core/remix/v1/*` API is available only when Core
is started with `--remix` (or `enable_remix=True` in isolated tests).
The default Core instance does not initialize the REMIX schema, and rejects
that namespace. Existing `core_inherit.initialize`, owned match participant
APIs, guest REMIX routes, session auth, origin/host checks and other Core
routes remain unchanged. The new service documents `playersPerMatch: 1`.
Challenges are comparable across distinct actor-owned runs; this is **not**
the existing two-player, invite-based live REMIX service and it does not
claim to supply Unity WebGL.

The independent client is at `/games/remix/arena/`; the current
`/games/remix/` page and Core/INHERIT account consoles remain untouched.
The UI negotiates the ruleset before enabling play, persists active ids
and idempotency keys safely for recovery, and displays actual server scores
and signed replay hashes, not client-produced results.

## Dedicated validation

`.github/workflows/core-remix-arena.yml` asserts core schema and
concurrent replay/idempotency behavior with a disposable SQLite DB, verifies
current legacy account-owned REMIX tests, builds the actual static frontend,
exercises HTTP through a loopback Core server, and tests real Chromium
including lost-response, account recovery, history and unsupported service
cases. The workflow does **not** deploy or contact production endpoints.

## Scope boundaries

PR128 additionally includes invasive backup/restore replacement logic and a
process-kill restore drill. Those are **not** incorporated here because
current master added an independent semantic INHERIT lineage verifier.
Backup integration must separately preserve that semantic gate, test
combined INHERIT+REMIX snapshots, verify the restored Core API, and keep
all operations strictly offline. No current production or staging restore
is claimed.

There is no Unity gameplay implementation, paid monetization,
public Lighthouse performance proof, production/staging deployment,
or master merge in this integration branch.
