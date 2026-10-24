# VECTOR//ZERO 1.3 — friend ghost challenges

## Gameplay
A successful personal-best run records bounded local positions. New **SHARE / BEST** copies a link like `/games/vector-zero/#race=<compact-code>`, and opening that link selects a transparent **FRIEND** ghost over the player's own local ghost. Players can race the shared trajectory without registration, and **FRIEND / EXIT** returns to their own best. Existing polarities, jumps, controls, saves and normal game launch remain intact.

## Data format and guardrails
- Only world X and Y coordinates and the completion time are sent in the URL fragment; **not** keyboard events, user IDs, emails, account or payment data.
- Encodes at about **two positions per second** using unsigned 16-bit coordinates, a centisecond duration field and version marker VZ/1.
- The compact URL fragment is limited to 2,100 base64url characters (max 361 samples and 180-second run); an FNV-1a integrity checksum rejects accidental corruption.
- Fragments are never sent to the HTTP server as part of requests, although anyone receiving the link can see the shared route. There is **no backend leaderboard and no anti-cheat authentication**.
- Invalid, oversized, checksum-mismatched or out-of-bounds challenges are rejected and the existing local game remains playable.
- Browser clipboard permission failure falls back to a manually copyable browser prompt.
- Best replay remains stored only in existing `localStorage` keys. Visiting a friend challenge does not change those keys. A visitor can exit the challenge without reloading.

## QA and deployment
- `node scripts/vector-zero-runtime-smoke.mjs` executes the shipped game with DOM/Canvas adapters, including share-link roundtrip, checksum mutation, oversized links, actual friend HUD interaction and clipboard fallback.
- `node scripts/vector-zero-production-smoke.mjs --self-test` tests release identity. The SSH deployment verifies published runtime SHA-256 against the release archive.
- Do not claim authenticated competition; these are fun, privately shareable, unverified coordinates.

## Manual acceptance on a browser
1. Clear saved ghost and open `/games/vector-zero/`: **SHARE / BEST** must be disabled.
2. Complete one actual level; SHARE becomes active.
3. Copy the link to another browser/device and open it. **FRIEND / ON** appears, with an explicit unverified-record notice.
4. Start racing and compare the path. Toggle FRIEND off and on, then EXIT.
5. Verify personal best stays unchanged and a malformed `#race=` cannot crash the game.
