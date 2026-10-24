# OSGARD R135 W5 — visual diagnostics candidate

## Implementation
- Three **simulated, in-world 3D diagnostic markers** for optical alignment, cooling airflow and service interlock. The optical marker is parented to the real animated optical head; markers only appear during the challenge and switch amber → green when inspected/completed.
- Optical inspection camera tracks the moving carriage horizontally and widens on narrow screens. Added QA telemetry `camera_effective_distance` and `optical_tracking`.
- Very short portrait viewports use smaller HUD fonts and buttons to preserve the visible game region. Desktop and the W4 training and diagnostic controls remain intact.
- All W4 faults are synthetic; no real sensor readings are connected. Existing HERO/ECO GLBs stay unchanged.

## Delivery contract and safety
- Candidate branch: `feat/r135-w5-visual-diagnostics-20261024`. Do not merge until Godot 4.4.1 import, native smoke, and Chromium desktop/mobile tests pass.
- W5 CI uses its own release manifest version `r135-web-visual-diagnostics-w5-20261024`. Production staging and production smoke are **still pinned to W4**, deliberately. No production deploy of W5 is claimed.
- After candidate tests pass, update `scripts/r135-release-stage.py`, `scripts/r135-production-smoke.mjs` and `.github/workflows/deploy-frontend.yml` together to accept the W5 immutable tag, then merge to master, publish asset and run deploy. Never change these production files until a tested W5 release is available.

## QA
1. Existing native Godot 4.4.1 smoke: 4-step training, 5-step diagnostics, locks, score, HERO/ECO, three marker presence.
2. WebGL2 SwiftShader real game run: desktop keyboard and emulated Pixel touchscreen; ensure original diagnostics paths pass.
3. Real Android and iOS GPU FPS, layout and thermal testing is still necessary before making AAA/mobile-performance claims.

## Known risk
- The W4 smoke checks mechanical state rather than pixel-perfect compositions; W5 visual review also needs saved 1366x768 and portrait screenshots.
- The W5 branch is not published to the live `/games/r135-service/` route.
