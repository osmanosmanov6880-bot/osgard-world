# R135 W13 — safety-first simulated maintenance mission

## Why this change is required

The previous four-action teaching sequence told the player to **OPEN SERVICE HATCH** before **PAUSE DRIVE**. Even though R135 is a self-contained simulation, teaching this order is an unacceptable educational failure. A running drive must never reward hatch access. Correcting the simulated training is separate from the W12 three-fault validation and does not automatically change published W11.

## Implemented code

The introductory mission now requires:

1. **STOP simulated drive** (motor no longer moving).
2. **OPEN simulated inspection hatch**; opening a moving mechanism is rejected with visible interlock feedback.
3. **CLOSE simulated hatch**; the animation must physically return to sealed position.
4. **RESTART simulated drive** only when the hatch is fully sealed and the ordered checkpoints are completed.

In both introductory mission and advanced diagnostic challenge:
- Opening the hatch while the simulated motor runs is rejected, with no change of lid target.
- Restart while hatch open or still closing is rejected; mission progress cannot advance.
- Restart before the correct ordered steps is rejected.
- Starting a new simulated scenario resets both target and interpolated hatch pose to closed.
- No external hardware integration, remote machine commands or sensor values are introduced.

## Quality gates

`godot/osgard-r135-standalone/tests/smoke.gd` now directly checks rejected opening while motor runs, rejected restart while hatch open/closing, intermediate hatch positions, and final four-action completion.

`scripts/r135-web-smoke.mjs` verifies the same using real Godot keyboard input and mobile touchscreen taps in Chromium. The full original W12 three-fault suite must also pass. Existing original GLB resources, W11 luminance, HTTP WASM/PCK and WebGL binary SHA gates remain mandatory.

## Important safety boundary

This is a **simulator**, not a maintenance instruction for any real industrial machine. Pausing a simulated drive is NOT electrical isolation or lockout/tagout. Actual maintenance requires equipment-specific procedures, authorized isolation, verification of zero energy and applicable safety training. No real devices can be operated by this software.

## Release control

W13 is a stacked PR on W12 and must not be merged into `master` before W12 is independently accepted and merged. No automatic W11 replacement: an updated playable export would require its own version number, exact source/manifest/ZIP SHA-256, immutable GitHub Release, production Nginx test, SSH rollback guard, public acceptance, and separately evidenced real-phone performance.
