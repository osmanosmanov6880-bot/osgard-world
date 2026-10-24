# VECTOR//ZERO 1.2 — GHOST RACE

## What shipped into the game source

- After a **successful** completion faster than the stored record, the game retains a small trajectory of the player's position, sampled at roughly 10 Hz.
- Replaying the stage shows the previous best route as a translucent violet operator, time-synchronized with the current run. The status line shows horizontal progress relative to the ghost at the same elapsed time.
- `GHOST / ON–OFF` works separately from `AIM / ON–OFF`. With no saved success the ghost control is visibly disabled.
- Best time and replay are **local to the device** and stored in browser localStorage. No telemetry upload, account data, payments or Stripe changes.
- Saved records are versioned. Oversized, malformed, non-finite and out-of-bounds saved coordinates are rejected. A refused localStorage access must never crash the game.
- Replay sampling stops at 180 seconds and 1,801 samples; longer successes still save their best time but have no ghost record.
- Ghost drawing uses a cheap Canvas overlay; it is skipped when disabled, outside the viewport, paused or after the replay finishes.
- Initial hero copy and catalogue details describe the real 2D game and the local-save behavior in Russian.

## Validation

`npm run qa:vector-zero` runs the **actual inline game runtime** with Canvas/DOM adapters. A test-only completion hook reaches the real `finish(true)` code path: this verifies storage and UI, **not that an AI-controlled player solved the level**. Existing physics, keyboard, touch, gamepad, hidden-tab and lifecycle tests remain active.

After code merge, the SSH deployment verifies the exact published VECTOR//ZERO script SHA-256 against the release package. Run human gameplay QA on desktop, mobile and controller independently to assess appearance, player skill and GPU performance.

## Browser QA

The general `OSGARD frontend validation` workflow runs `scripts/vector-zero-ghost-browser.spec.mjs` on real Chromium desktop and mobile projects, checking seeded personal-best replay controls, active gameplay, polarity, pause/restart and malformed-storage fallback. Screenshots/traces are retained on browser failure.
