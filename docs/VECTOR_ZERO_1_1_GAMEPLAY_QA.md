# VECTOR//ZERO 1.1 — gameplay and runtime quality

## Implemented in the shipped game

- **Jump buffering** (140 ms) and **coyote time** (110 ms): forgiving but deterministic platforming.
- Landing collision uses the player's previous foot position to avoid sticking on side walls.
- Camera follows the player with frame-rate-independent smoothing.
- Layered deterministic industrial skyline adds parallax depth without external texture downloads.
- Mobile canvas uses uniform letterboxing instead of stretching circular magnets into ovals.
- Predictive magnetic trajectory is cached for 50 ms rather than simulated on every draw, and can be switched off with an accessible AIM control.
- Press-and-hold repeat on Q, E, Space, R and jump no longer triggers accidental multiple actions.
- Gamepad support: analog left stick or D-pad, A jump, X launch, Y polarity, B pulse, Start pause/resume. Button edges are debounced and disconnects clear movement.
- The attempt automatically pauses when the tab becomes hidden and skips Canvas rendering while hidden; it never resumes itself without a player action.
- Short mission status messages remain visible until their timer expires.
- Best successful time is stored locally with storage-failure protection. No account tracking or payment changes.
- Reduced-motion preference disables transient particle bursts and moving star twinkle; keyboard focus is visible.

## Quality checks

Run `npm run qa:vector-zero` or `node scripts/vector-zero-runtime-smoke.mjs`. The test executes the real inline game with a Canvas/DOM adapter, not a separate physics reimplementation. It covers pause/resume, touchscreen, buffered jump, coyote time, input auto-repeat and render validity.

**Scope:** Browser visuals, GPU performance and production deployment still require separate real-device checks. This is a 2D Canvas game, not a photorealistic Unreal Engine build.
