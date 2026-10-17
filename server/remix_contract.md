# REMIX arena v1: optional local authoritative service

This repository now contains an **opt-in arena slice**, identified by
`service: osgard-remix-arena` and `ruleset: remix-arena-v1`. It uses the existing
OSGARD Core accounts and SQLite database. The implementation is in
`server/remix_service.py`, with the opt-in HTTP dispatch in `core_server.py`.

This is a new compatible local service, not a reconstruction of an unavailable
external backend. The existing deployment files refer to a separate
`../remix/backend` project (`docker-compose.production.yml`) and an independent
`remix-api:8080` upstream (`nginx.conf`). That source is not present in this
checkout or the inspected workspace. Those production routes are unchanged.
The Unity player at `/games/remix/player/index.html` remains separate; this arena
does not claim to supply its protocol, physics or multiplayer implementation.

## Enable it locally

```sh
npm run build
python3 server/core_server.py --root dist --database /tmp/osgard-remix.sqlite3 --port 4173 --remix
```

Open `http://127.0.0.1:4173/games/remix/`. Without `--remix`, Core behaves as
before: it creates no REMIX tables and returns `404 remix_disabled` for REMIX API
requests. `create_server(..., enable_remix=False)` and the Store constructor keep
the flag optional and last in their signatures. The SQLite file must remain
outside the static document root. This is a local launch example, not a change
to production compose/nginx or an instruction to publish the service.

The browser first reads `/api/remix/v1/capabilities`. It requires the exact
schema/service/ruleset/auth/result-authority contract and `playersPerMatch: 1`.
A missing or incompatible service leaves gameplay disabled with a concrete
message. A legacy service without this capability is not silently treated as
the arena service.

## Authentication and ownership

The UI uses the existing Core session format: the raw bearer token stored in
`sessionStorage['osgard:core-session:v1']`. It verifies the session through
`GET /api/core/auth/me`. Registration and login use the existing Core endpoints
and password rules. Tokens are never shown in game labels, links, result cards
or QA reports. The browser sends Core credentials only to same-origin Core and
REMIX API paths; there is no arbitrary API URL field.

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

All routes below are relative to `/api/remix/v1/`. JSON success responses include
`schemaVersion: 1`; challenge/state/result responses identify the ruleset.

| Method and route | Input | Result / boundary |
| --- | --- | --- |
| `GET capabilities` | none; anonymous | Exact service/auth/ruleset, limits, one-player mode, server-input-journal authority |
| `POST challenges` | `title`, integer `seed`; optional `mode: speed`, `visibility: public/private`, `creatorId`, `objects` | New owned `DRAFT`; arbitrary score/state fields are rejected |
| `GET challenges/:id` | bearer | Owned draft/private challenge or published public challenge, including exact arena |
| `POST matches` | `challengeId`, optional `maxPlayers: 1` | New owned `PLAYING` run, initial position, arena, purpose and sequence 0 |
| `GET matches/:id/state` | owner bearer | Persisted server state and arena; another actor receives 404 |
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

## Result and replay integrity

Each accepted input writes an ordered input record and a checkpoint containing
the full calculated state and its canonical SHA-256 hash. The final envelope
includes the game/ruleset version, seed, challenge ID, match ID, actor ID, purpose,
arena, initial state, ordered inputs, checkpoints and derived result. Its hash
covers every field except the `hash` field itself.

Reads of completed results/replays re-simulate the entire input journal and check
every checkpoint and result. The persisted full result record (including actor,
scores, purpose and ruleset) and final state must exactly match the derived data.
Validation/publication also verify that the creator proof belongs to this exact
challenge, has purpose `creator-proof`, and ended in a win; publication repeats
those checks instead of trusting a persisted proof pointer. The leaderboard selects at
most 20 best-per-actor rows in SQL and verifies the selected journals before
returning scores. A detected integrity mismatch returns 503, not a plausible
score. Tests explicitly corrupt result metadata, scores, the final state and
checkpoints to prove this behavior.

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
- The implementation retains immutable challenge arenas. The browser can choose
  a seed/title and fork an existing field; it is not a complete visual level
  editor. The existing `src/core/remixState` prototype is separate and unchanged.
- Core's existing deployment/security/backup constraints still apply. No
  production service was configured, redirected, published or written by QA.

## Reproducible acceptance

```sh
# Pure contract/growth checks and meaningful real HTTP/SQLite regressions
npm run qa:remix-growth
python3 -m unittest discover -s tests -p 'test_remix*.py' -v
npm run qa:remix-server

# Full shared browser matrix, backed by disposable Core + REMIX + SQLite
python3 scripts/games-local-acceptance.py --dist dist --out test-results/games-browser

# Focused REMIX UI only, or explicit auth/availability/lost-response regressions
python3 scripts/games-local-acceptance.py --dist dist --only remix --devices desktop,mobile
python3 scripts/remix-ui-acceptance.py --dist dist --out test-results/remix-ui

# Only the real native-touch and delayed-snapshot regressions
python3 scripts/remix-ui-acceptance.py --dist dist --only poll --out test-results/remix-poll

# For a Cloudflare-packaged directory with the existing gzip WASM header/bytes
python3 scripts/games-local-acceptance.py --dist packaged-dist --cloudflare-headers
```

Chromium must be installed for browser commands. The shared launcher supplies
only temporary Core tokens through the child environment and same-origin browser
session initialization. The report contains IDs, hashes, assertions and counts,
not passwords/tokens. It runs a real two-actor HTTP proof/publication/challenger
flow before starting the game matrix, and cleans up its temporary database.

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
