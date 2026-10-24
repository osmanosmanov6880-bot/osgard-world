# OSGARD R135 W5 — visual diagnostics candidate

## Implementation
- Three **simulated, in-world 3D diagnostic markers** for optical alignment, cooling airflow and service interlock. The optical marker is parented to the real animated optical head; markers only appear during the challenge and switch amber → green when inspected/completed.
- Optical inspection camera tracks the moving carriage horizontally and widens on narrow screens. Added QA telemetry `camera_effective_distance` and `optical_tracking`.
- Very short portrait viewports use smaller HUD fonts and buttons to preserve the visible game region. Desktop and the W4 training and diagnostic controls remain intact.
- All W4 faults are synthetic; no real sensor readings are connected. Existing HERO/ECO GLBs stay unchanged.

## Delivery contract and safety
- Candidate branch: `feat/r135-w5-visual-diagnostics-20261024`. Do not merge until Godot 4.4.1 import, native smoke, and Chromium desktop/mobile tests pass.
- W5 CI creates the release manifest `r135-web-visual-diagnostics-w5-20261024` **only after** Godot, WebGL, Nginx, checksum and touchscreen checks succeed. Publication is from the W5 feature-branch job only, with no automatic overwriting of that tag.
- Production staging, production smoke and frontend deployment have been **prepared in this unmerged PR**, pinned to the W5 tag and exact validated source SHA `668e42716aaefb0c45eb5347abe9355437dc4b69`. Live `master` still serves W4 until the PR is approved and merged. No W5 production deploy is claimed.
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
