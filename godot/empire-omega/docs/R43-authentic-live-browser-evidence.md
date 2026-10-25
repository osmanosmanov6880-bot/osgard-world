# EMPIRE OMEGA R43 — live Chromium release evidence correction

Root cause observed on GitHub Actions run 40166190523: the desktop Chromium test
reached the final real gameplay screenshot, but page.screenshot() timed out
after 45 seconds on an actively painted Godot 4.4.1 WebGL viewport. The same
native source had successfully passed the preceding live release test.

The existing authenticated helper is now used at *every* screenshot point:
initial world, after entering vehicle, after real two-finger input, and after
all game commands. Chromium DevTools is preferred, actual live Godot canvas
readback is bounded fallback, and Playwright screenshot is final fallback.
Every path must return valid non-trivial PNG pixel bytes or fail; all original
mobile scene-coverage, entry motion and driving pixel-difference assertions
remain unchanged. No screenshots from stock images, static HTML, synthetic
frames or reference assets can satisfy the check.

Strict production gates: unchanged exact manifest SHA/WASM/PCK, unchanged
native engine 4.4.1, no playability claims from unit-only tests. R43 modifies
release QA, not the built game and not the public server.

Always verify publication and user-visible behaviour by actual release
manifest and fresh WebGL browser acceptance.
