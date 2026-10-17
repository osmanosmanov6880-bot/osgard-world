# REMIX arena v1: optional local authoritative service

This repository now contains an **opt-in arena slice**, identified by
`service: osgard-remix-arena` and `ruleset: remix-arena-v1`. It uses the existing
OSGARD Core accounts and SQLite database. The implementation is in
`server/remix_service.py`, with the opt-in HTTP dispatch in `core_server.py`.

The arena has its own UI at `/games/remix/arena/` and Core-owned API namespace
`/api/core/remix/v1/`. The established match console remains at `/games/remix/`,
with `/api/remix/` routed through `remix-guard:8081` to the independent legacy
`remix-api:8080` service. The two services have different session, state and
result contracts. Core rejects the reserved legacy API paths instead of
interpreting their requests as arena operations. The existing Core reverse
proxy already forwards the arena namespace; its opt-in flag remains disabled
in production Compose.

The Unity route `/games/remix/player/index.html` retains PR130's unavailable
status. Its normal page does not load the engine; an explicit diagnostic route
remains available for inspection. The Core arena supplies its own game rules,
without making claims about Unity physics or multiplayer compatibility.

## Enable it locally

```sh
npm run build
python3 server/core_server.py --root dist --database /tmp/osgard-remix.sqlite3 --port 4173 --remix
```

Open `http://127.0.0.1:4173/games/remix/arena/`. Without `--remix`, Core behaves as
before: it creates no REMIX tables and returns `404 remix_disabled` for REMIX API
requests. `create_server(..., enable_remix=False)` and the Store constructor keep
the flag optional and last in their signatures. The SQLite file must remain
outside the static document root. This is a local launch example, not a change
to production compose/nginx or an instruction to publish the service.

The browser first reads `/api/core/remix/v1/capabilities`. It requires the exact
schema/service/ruleset/auth/result-authority contract and `playersPerMatch: 1`.
A missing or incompatible service leaves gameplay disabled with a concrete
message. A legacy service without this capability is not silently treated as
the arena service.

## Authentication and ownership

The UI uses the existing Core session format: the raw bearer token stored in
`sessionStorage['osgard:core-session:v1']`. It verifies the session through
`GET /api/core/auth/me`. Registration and login use the existing Core endpoints
and password rules. Tokens are never shown in game labels, links, result cards
or QA reports. The browser sends Core credentials only to same-origin Core auth
and `/api/core/remix/v1/` paths. The read-only diagnostic field cannot change
request routing, and the legacy match API does not receive the Core bearer.

Only the capability request is anonymous. Every challenge/run operation resolves
its actor from the Core bearer session. Optional `creatorId` or `playerId` fields
must match that actor. They cannot impersonate another account. Existing Core
host/origin checks also apply to REMIX.

Drafts and private challenges are visible only to their creator. Published public
challenges can be read and attempted by other authenticated actors. Every run,
state, result and complete replay remains private to its player. A leaderboard
shares only the best published-challenge run per actor, capped at 20 entries.

The optional legacy analytics session (`osgard.auth.accessToken`) remains separate
from Core auth. If absent, no player-events upload is attempted. The UI never
forwards a Core bearer token to the player-events API.

## Supported flow

1. An actor creates a draft challenge with a title, seed and generated arena (or
   a bounded object array through the API).
2. The creator starts a `creator-proof` run and supplies directional inputs.
3. The server advances the simulation, writes each input and checkpoint, and
   computes the completed result.
4. The creator validates that successful proof, then publishes the challenge.
5. Any permitted second actor starts their own `challenge` run on exactly the
   published arena. The server stores and ranks that actor's result separately.
6. A permitted actor can fork a published challenge through `/remix`; the child
   has a new owner and identity, retains its parent ID, and starts as a draft
   requiring a new creator proof.

There is **one player per run**. Two actors compare separate attempts on the same
published challenge. `maxPlayers: 2` returns `409 unsupported_players`. This
version does not implement a simultaneous room, opponent synchronization or a
general platformer engine.

## HTTP routes

All routes below are relative to `/api/core/remix/v1/`. JSON success responses include
`schemaVersion: 1`; challenge/state/result responses identify the ruleset.

| Method and route | Input | Result / boundary |
| --- | --- | --- |
| `GET capabilities` | none; anonymous | Exact service/auth/ruleset, limits, one-player mode, server-input-journal authority |
| `POST challenges` | `title`, integer `seed`; optional `mode: speed`, `visibility: public/private`, `creatorId`, `objects` | New owned `DRAFT`; arbitrary score/state fields are rejected |
| `GET challenges/:id` | bearer | Owned draft/private challenge or published public challenge, including exact arena |
| `POST matches` | `challengeId`, optional `maxPlayers: 1` | New owned `PLAYING` run, initial position, arena, purpose and sequence 0 |
| `GET matches` | bearer; optional `status`, `limit`, `cursor` | One page of the actor's active or completed run metadata; every summary has `stateVerified: false` |
| `GET matches/:id/state` | owner bearer | State and arena verified against the complete committed input prefix; another actor receives 404; an inconsistent prefix receives `503 replay_integrity` |
| `POST matches/:id/input` | `sequence`, cardinal `moveX/moveY`, optional Boolean `jump`, optional matching `playerId` | Accepted sequence and complete server state; input order and identity are enforced |
| `GET matches/:id/result` | owner bearer | Completed derived result plus `replayHash`/`replayKey`; unfinished run receives 409 |
| `GET matches/:id/replay` | owner bearer | Complete versioned arena/input/checkpoint/result envelope and SHA-256 hash |
| `POST challenges/:id/validate` | `matchId` | Creator's successful proof for this exact challenge changes it to `VALIDATED` |
| `POST challenges/:id/publish` | `{}` | Revalidates proof, then changes `VALIDATED` to `PUBLISHED` |
| `GET challenges/:id/leaderboard` | permitted bearer | Up to 20 best-per-player winning `challenge` runs; proof runs are excluded |
| `POST challenges/:id/remix` | optional `title`, `seed`, `objects` | New actor-owned draft with `parentId`; source must be published and accessible |

Every POST requires `Idempotency-Key` with 16–100 alphanumeric/underscore/hyphen
characters. A key is scoped to the authenticated actor and bound to the canonical
route + JSON body. An exact retry returns the recorded response with
`replayed: true`; changing its request returns 409. A repeated input sequence with
the same normalized intent also returns its saved response. A conflicting
sequence or skipped sequence is rejected. The journal, state and operation record
commit in the same SQLite transaction.

### Owned run history

`GET /api/core/remix/v1/matches` recovers the authenticated actor's run references
even if the browser's saved match reference has been lost. It never creates a run,
updates a session or changes game state. Authentication precedes history query
validation; an anonymous request receives 401.

| Query field | Default | Accepted value |
| --- | --- | --- |
| `status` | `active` | `active` selects `PLAYING`; `complete` selects `RESULTS` |
| `limit` | `20` | A decimal integer from 1 to 50, without a sign, leading zero or fractional part |
| `cursor` | absent | A 32-character lowercase hexadecimal ID of a run owned by this actor |

Only these three fields are accepted, once each. The raw query is limited to 256
characters and three fields. Unknown fields, duplicate fields (including encoded
aliases), blank values and malformed query segments receive 400. Invalid status
or limit values also receive 400. A malformed, nonexistent or other actor's cursor
receives `400 invalid_cursor`; the latter two have the same response. This contract
does not accept an offset or a caller-supplied actor ID.

The response has `schemaVersion: 1`, `matches` and `nextCursor`. Each summary
contains only `id`, `challengeId`, `title`, `phase`, `purpose`, `createdAt` and
`stateVerified: false`. Both creator-proof runs and challenge attempts appear in
their owner's history. No result, score, position, input journal or credential is
included. A summary is an unverified reference: opening it requires the owned
`GET matches/:id/state` integrity check before the browser restores play or reads a
completed result/replay. A damaged run can therefore remain listed while opening
it correctly returns 503.

Rows are ordered by `createdAt` descending, then run ID descending. The cursor
selects rows strictly after that pair in the same order. SQL filters ownership and
phase and reads at most `limit + 1` rows. `nextCursor` is the last returned run ID
when another row exists, otherwise `null`. Cursor validity depends on ownership,
so a run that finishes between page requests remains a valid history position.
Each page uses one database snapshot; separate pages are not a frozen snapshot of
all runs. Unsupported versions, a trailing slash or an invalid child route do not
dispatch to history. Core continues to reject reserved legacy API paths.

### Pending operations and browser restoration

The browser persists an unacknowledged operation's key, body and actor in session
storage. It sends only one input at a time and changes the rendered player only
after a server response. A lost response may follow a committed transaction:
retry uses the same key after reload, without adding a second move. The recovery
button makes this state explicit. Definite 4xx rejections other than 401 clear that
pending operation so the user can resolve the error. A 401 only rejects the
current retry: the original attempt may already have committed. The saved actor,
key and payload survive that rejection and reload; signing in as the same actor
can acknowledge the same entity. A different actor cannot reuse the saved
operation. Expired auth returns to the existing Core login flow.

Restoration keeps the saved challenge/match reference unchanged until the full
read succeeds. Loading a challenge alone cannot overwrite the saved match ID.
An explicit restoring state blocks new match creation during the read and after
a transient failure; a separate recovery button retries that saved run. Reload
also retries the same reference. This prevents a failed state read from silently
starting a duplicate run.

Background reads have their own in-flight guard and do not disable movement
controls. Disabling a button between native touchstart and touchend can discard
the user's click, even when the network request itself succeeds. User writes
remain serialized by the action/pending-operation logic. A late state response
must still belong to the current actor, bearer session and match; older sequences
cannot replace a newer confirmed move or result. Errors from an obsolete read
likewise cannot expire a newly established session.

## Deterministic arena and scoring

The arena has 12 × 7 cells and starts at `[0, 3]`. A seed selects two wall columns
with gaps and up to three hazards while retaining a safe walking route to one
goal. An explicit arena has 1–40 uniquely named/non-overlapping objects of type
`platform`, `hazard` or `goal`; coordinates are bounded integers, the start is
unoccupied, there is exactly one goal, and a safe walking path must exist.

An input moves one cardinal cell, or two with `jump: true`. A jump cannot cross a
platform. The destination must be in bounds. A blocked move still consumes a
step. Landing on a hazard resets the position to the start and adds a fall;
jumping over a hazard is permitted. Reaching the goal wins. At 256 inputs the run
ends even if the goal was not reached.

The server computes:

```text
timeMs = steps × 100 + jumps × 100 + falls × 1500
score = won ? max(0, 100000 - timeMs) : 0
```

This is simulation time, not wall-clock latency. The UI explains the distinction.
It supports arrow/WASD keys, Space to jump in the last direction, four touch
direction buttons and a touch jump button. The result card displays actual server
values and distinguishes a win from the input limit. Sharing is enabled only
after publication. The sponsor panel is a labelled inquiry after a confirmed
result, with no claim of an active paid campaign.

## Active prefix, result and replay integrity

Each accepted input writes an ordered input record and a checkpoint containing
the full calculated state and its canonical SHA-256 hash. The final envelope
includes the game/ruleset version, seed, challenge ID, match ID, actor ID, purpose,
arena, initial state, ordered inputs, checkpoints and derived result. Its hash
covers every field except the `hash` field itself.

`verified_prefix` re-simulates every committed input from the initial state before
returning a run's state, accepting its next input or serving a cached input retry.
It accepts valid prefixes of 0 through 256 inputs. It verifies the immutable arena,
contiguous sequence numbers, canonical input values, every checkpoint and hash,
every saved input acknowledgment, the persisted full state and its phase. An
active run must not already contain a result or replay hash. A stored snapshot is
never used as an unchecked starting point for the next move.

The same verification runs for a retry with its original `Idempotency-Key` and for
a repeated sequence under a new key. A valid retry returns its original historical
acknowledgment with `replayed: true`, without another input or state advance; it is
not a new current-state snapshot. The caller must retain its sequence guard when
later inputs have already been confirmed. A damaged prefix or cached input
acknowledgment returns `503 replay_integrity`. Rejected reads, new inputs and
cached retries leave match, input and operation rows unchanged; no repair or
partial write is attempted.

Verification uses the caller's single database snapshot. Input mutations hold
`BEGIN IMMEDIATE` while verifying and extending it. No previously verified prefix
is cached across connections. The input query reads at most 257 rows, using the
last row only to detect overflow beyond the 256-input cap. Each stored JSON value
read by this verification is limited to 16 KiB of UTF-8 and rejects duplicate
object keys and non-finite numbers. Existing valid records need no migration; the
arena ruleset, checkpoint format, response bodies and table schema are unchanged.

Reads of completed results/replays also verify the entire input prefix. The
persisted full result record (including actor, scores, purpose and ruleset), final
state and replay hash must exactly match the derived data.
Validation/publication also verify that the creator proof belongs to this exact
challenge, has purpose `creator-proof`, and ended in a win; publication repeats
those checks instead of trusting a persisted proof pointer. The leaderboard selects at
most 20 best-per-actor rows in SQL and verifies the selected journals before
returning scores. A detected integrity mismatch returns `503 replay_integrity`.
Tests corrupt active snapshots, inputs, checkpoints, saved acknowledgments,
operation-cache responses, result metadata and final states to exercise these
boundaries.

SHA-256 is an integrity check, not a secret signature or proof against a hostile
database administrator. The server owns scoring and sequence validation; this
slice does not claim bot detection, anti-automation or competitive anti-cheat.
The fields visible to an authenticated player are sufficient to solve a route
programmatically, as the browser acceptance test does through normal UI inputs.

## Limits and operational scope

- Core already bounds JSON request bodies to 256 KiB. REMIX accepts only declared
  fields and typed values; scores, positions and arbitrary client state cannot be
  submitted as authoritative inputs.
- An actor is limited to 100 challenges, 500 runs and 40,000 operation records.
  Each run has at most 256 input/checkpoint rows. These are persisted quotas;
  there is no new admin or retention API in this slice.
- A leaderboard contains at most 20 verified rows and one best run per actor.
  This is a bounded local SQLite service, not an internet-scale ranking service.
- Owned history defaults to 20 summaries per page and permits at most 50. It
  reads metadata without replaying every listed run; opening a run verifies that
  run's bounded journal.
- The implementation retains immutable challenge arenas. The browser can choose
  a seed/title and fork an existing field; it is not a complete visual level
  editor. The existing `src/core/remixState` prototype is separate and unchanged.
- Core's existing deployment/security/backup constraints still apply. Arena QA
  writes only to disposable loopback servers. Enabling the arena for production
  remains a separate action. The active arena drill starts Core explicitly with
  `--remix` and uses its guarded SQLite backup/restore helpers. Its snapshot at
  input 4 restores exactly input 4, while a separate crash/restart of the source
  retains input 5 acknowledged after the snapshot. This local check does not
  establish production RTO/RPO or cover the legacy guard's independent
  `osgard-remix-guard-data` volume or legacy engine recovery.

## Reproducible acceptance

```sh
# Pure contract/growth checks and meaningful real HTTP/SQLite regressions
npm run qa:remix-growth
python3 -m unittest discover -s tests -p 'test_remix*.py' -v
npm run qa:remix-server

# Focused service, real history HTTP and active recovery suites
python3 -m unittest discover -s tests -p test_remix_service.py -v
python3 -m unittest discover -s tests -p test_remix_history_http.py -v
python3 -m unittest discover -s tests -p test_remix_recovery_http.py -v

# Real active-run snapshot, crash/restart and independent restore; use NEW paths
python3 scripts/remix-recovery-drill.py \
  --work-dir /tmp/osgard-remix-active-recovery-example \
  --report /tmp/osgard-remix-active-recovery-example-report.json

# Full shared browser matrix, backed by disposable Core + REMIX + SQLite
python3 scripts/games-local-acceptance.py --dist dist --out test-results/games-browser

# Focused REMIX UI only, or explicit auth/availability/lost-response regressions
python3 scripts/games-local-acceptance.py --dist dist --only remix --devices desktop,mobile
python3 scripts/remix-ui-acceptance.py --dist dist --out test-results/remix-ui

# Only the real native-touch and delayed-snapshot regressions
python3 scripts/remix-ui-acceptance.py --dist dist --only poll --out test-results/remix-poll

# Only the owned-history / browser restoration regressions
python3 scripts/remix-ui-acceptance.py --dist dist --only history --out test-results/remix-history

# For a Cloudflare-packaged directory with the existing gzip WASM header/bytes
python3 scripts/games-local-acceptance.py --dist packaged-dist --cloudflare-headers
```

Chromium must be installed for browser commands. The shared launcher supplies
only temporary Core tokens through the child environment and same-origin browser
session initialization. The report contains IDs, hashes, assertions and counts,
not passwords/tokens. It runs a real two-actor HTTP proof/publication/challenger
flow before starting the game matrix, and cleans up its temporary database.

The active recovery drill creates private synthetic accounts and a new disposable
database, publishes a creator proof, backs up an active challenger, acknowledges a
later input and kills the source process. It checks source crash durability and
the earlier restored recovery point separately, then compares every resumed
acknowledgment, the result and the complete replay with the source continuation.
An independent corrupted restore must reject state reads, fresh input and a cached
retry without changing arena rows. Its publishable JSON contains only assertions,
counts, timings and hashes; the work directory contains private test data and must
not be published. The local 2026-10-17 evidence and exact limits are recorded in
[the active recovery report](../docs/REMIX-ACTIVE-RECOVERY-2026-10-17.md).

Four history browser scenarios exercise recovery after browser storage loss,
account separation, keyset pagination, reopening a completed result/replay, and a
history-session rejection concurrent with a committed input acknowledgment. The
active recovery report records their local execution in the 14-scenario UI suite
separately from the service, HTTP and recovery test results.

The browser scenario independently re-simulates the Python-generated replay in
JavaScript, compares all checkpoints and result fields, uses real keyboard/touch
inputs, reloads a live run, verifies publication/ranking, scrubs the replay and
reads the downloaded PNG header/dimensions. It never fulfils a route with a fake
success or writes a game state setter. Missing/incompatible service classification
requires a real capability request; a compatible backend with a broken client is
a failed check, not an expected blocker.

The focused UI regression launcher uses real Core servers. One negative fixture
deliberately advertises an unsupported capability and must remain disabled. One
fault fixture drops the first input response **after** the real transaction
commits. The final SQLite assertions require exactly one input row and three
operation rows (create, match, input) after the browser retries. These fixtures
test failure behavior; neither substitutes a successful game response. Additional
CREATE and MATCH response-loss tests revoke the real Core session before retry,
observe 401, sign in again, and require the original committed entity with exactly
one challenge, one match and two operation rows. Transient state-read fixtures
return an actual local 503 and verify both button retry and reload recovery, with
new match creation disabled during/after the failed read and exactly one persisted
run afterwards.

Two additional polling regressions delay actual SQLite-derived GET responses,
without replacing their contents. One native touch spans a polling boundary and
must submit exactly one input; a late sequence-0 snapshot cannot roll back the
confirmed sequence 1. Another snapshot of the previous run is held until a new
run has started, then delivered; it must not change the new run or its saved ID.

The packaged serving option validates the exact
`/games/null-shift-godot/*.wasm` gzip header rule and gzip file magic before launch.
Its QA-only Handler adds `Content-Encoding: gzip` only for
`/games/null-shift-godot/index.wasm`. Exact missing `/games/time[/]` and `/play[/]`
paths use the SPA entry; missing Godot/game assets remain 404. This does not
change production Core static serving. Any exception after successful checks
forces a failed report and nonzero exit; dedicated regression tests cover that
previously possible false success.
