# OSGARD R135 W5 — visual diagnostics candidate

## Implementation
- Three **simulated, in-world 3D diagnostic markers** for optical alignment, cooling airflow and service interlock. The optical marker is parented to the real animated optical head; markers only appear during the challenge and switch amber → green when inspected/completed.
- Optical inspection camera tracks the moving carriage horizontally and widens on narrow screens. Added QA telemetry `camera_effective_distance` and `optical_tracking`.
- Very short portrait viewports use smaller HUD fonts and buttons to preserve the visible game region. Desktop and the W4 training and diagnostic controls remain intact.
- All W4 faults are synthetic; no real sensor readings are connected. Existing HERO/ECO GLBs stay unchanged.

## Delivery contract and safety
- Candidate branch: `feat/r135-w5-visual-diagnostics-20261024`. Do not merge until Godot 4.4.1 import, native smoke, and Chromium desktop/mobile tests pass.
- W5 CI creates the release manifest `r135-web-visual-diagnostics-w5-20261024` **only after** Godot, WebGL, Nginx, checksum and touchscreen checks succeed. Publication is from the W5 feature-branch job only, with no automatic overwriting of that tag.
- Production staging, production smoke and frontend deployment have been **prepared in this unmerged PR**, pinned to the W5 tag and exact validated source SHA `cd6132fa5d34cbb701957b124a6aa2aac9210434`. Live `master` still serves W4 until the PR is approved and merged. No W5 production deploy is claimed.
- Before merge: require a successful candidate release and a downloadable W5 ZIP+manifest. The three production files above are already staged together **inside this isolated PR**. Verify the manifest's `source_commit` matches the pinned SHA, then merge and allow the existing SSH deploy to install the authenticated W5 pack. If W5 build fails, keep PR open and public W4 untouched.

## QA
1. Existing native Godot 4.4.1 smoke: 4-step training, 5-step diagnostics, locks, score, HERO/ECO, three marker presence.
2. WebGL2 SwiftShader real game run: desktop keyboard and emulated Pixel touchscreen; ensure original diagnostics paths pass.
3. Real Android and iOS GPU FPS, layout and thermal testing is still necessary before making AAA/mobile-performance claims.

## Known risk
- The W4 smoke checks mechanical state rather than pixel-perfect compositions; W5 visual review also needs saved 1366x768 and portrait screenshots.
- The W5 branch is not published to the live `/games/r135-service/` route.

## Additional W5 test coverage
- Native Godot smoke now completes all three scenarios (optics, cooling, interlock), verifies moving-head marker attachment and scene summary states.
- Chromium desktop and emulated Pixel touchscreen test actual 3D indicator states, the inspected/cleared transition and narrower portrait camera distance compensation. CI captures additional screenshots of the W5 optical view.

## W5 browser evidence and release gate
- First W5 candidate job `40081630110`: Godot and browser gameplay passed (desktop 89, emulated Pixel 69). The Nginx gate failed because the checked-out W4 production smoke required a W4 manifest against the W5 candidate. Production W4 remained intact.
- Corrected by allowing production smoke's expected source SHA to be supplied through environment; the W5 candidate Nginx test now uses `github.sha`. The production frontend workflow additionally pins the expected candidate SHA.
- Re-run must pass both Nginx and archive publication before PR merge. Hardware FPS remains unmeasured.

## 2026-10-24 — GitHub Releases permission fallback
- W5 complete run `40082233653` passed native Godot, desktop+mobile Chromium, 206 partial PCK and actual Nginx WASM gzip/MIME. The last `gh release create` step failed HTTP 403 from the Actions integration. **Gameplay binary is valid, GitHub Release was not created**.
- The SHA-verified W5 ZIP and source manifest were retained as Actions artifact `12556235053` (`osgard-r135-optimized-web-qa`) attached to run `40082233653`.
- Candidate promotion gate `.github/workflows/r135-w5-artifact-gate.yml` verifies a cross-run download of that exact artifact, not an arbitrary latest package.
- Production frontend staging now downloads that exact run artifact, validates all CRC/ZIP entry hashes and source commit `cd6132fa5d34cbb701957b124a6aa2aac9210434`, and tests staged Nginx before deployment.
- This Actions artifact has limited retention; a durable archive location is still needed for emergency rebuilds after expiration. Keep the working W4 untouched until the new promotion gate and SSH production smoke pass.
