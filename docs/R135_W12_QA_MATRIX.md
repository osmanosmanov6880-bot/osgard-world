# OSGARD R135 W12 — full diagnostic QA and physical evidence capture

**Status:** W12 is an **unreleased QA/harness improvement**. The published W11 remains live and has a verified permanent archive plus W6.4 rollback. This document never claims actual on-device measurements or AAA photorealism.

## Block A: genuine 3-case browser gameplay

`scripts/r135-web-smoke.mjs` now drives the real Godot canvas on desktop Chromium and Playwright's Pixel 7 touch emulation, verifying all three simulated faults without modifying controller internals.

| Scenario | Fault index | Camera | Required real UI actions | Safety blockers |
|---|---:|---:|---|---|
| Optical alignment | 0 | 2 | stop → hatch → inspect → seal → restart | running hatch, premature scan, wrong view, premature restart |
| Cooling airflow | 1 | 3 | stop → hatch → inspect → seal → restart | running hatch, wrong view, premature restart |
| Service interlock | 2 | 1 | stop → hatch → inspect → seal → restart | running hatch, wrong view, premature restart |

For EACH browser:
- Must load original Godot ECO GLB, show 8 controls, and have zero asset/runtime errors.
- Each fault has a unique 3D marker and label in the engine, with simulated-only evidence.
- All 5 steps are executed via actual desktop keys or touchscreen taps, not direct state mutation.
- Must reject the incorrect view, moving-hatch start and running-drive hatch access, with exactly the expected penalties.
- Must record three distinct cleared cases, one score per case and retain original W11 optical image/HUD/readability gates.
- Real unmodified Chromium PNG and per-case JSON are exported as Actions evidence; they are **software-renderer evidence**, not a real phone.

Acceptance requires successful `OSGARD R135 optimized web candidate` on the exact branch HEAD, genuine HTML5 Godot import/export, source SHA, screenshot review, full archive hashes and candidate Nginx gzip WASM / PCK HTTP 206.

## Block B: raw device frame callback observation

On a **real, authorized physical Android phone**, open `https://osgard.world/games/r135-service/` and explicitly choose **ECO** or **HERO** inside the actual game. Connect ADB USB debugging only to the developer workstation. Never expose remote CDP ports.

```bash
adb devices
adb forward tcp:9222 localabstract:chrome_devtools_remote

node scripts/r135-device-evidence.mjs \
  --cdp http://127.0.0.1:9222 \
  --url https://osgard.world/games/r135-service/ \
  --seconds 60 --mode ECO \
  --out evidence/r135-android-eco.json \
  --physical-device-attested

adb forward --remove tcp:9222
```

Repeat with HERO and `--out evidence/r135-android-hero.json`. Record model, OS, Chrome, battery, approximate ambient temperature and actual touches/diagnostics separately. If verifying another release, explicitly provide all three `--expect-version`, `--expect-source`, `--expect-manifest-sha256`; the defaults are SHA-pinned to the original published W11.

The harness fails closed on mismatched release SHA, changed quality mode, invalid raw frame intervals, insufficient visible samples or non-local CDP. It saves the ORIGINAL PNG hash, raw 250 ms Godot FPS observations, and unfiltered consecutive visible-page `requestAnimationFrame` intervals.

It derives browser callback P95/P99 intervals, worst 1% average callback pacing, and stall fraction. These are **not** GPU frametimes and must never be presented as verified gaming 1% low, device temperature, touch latency or battery impact. `--physical-device-attested` is a **user assertion**, not an independently proven hardware identity. A 60 second capture alone does not certify hardware usability, heat, frame delivery or safe real-world machine operation.

## Block C: actual acceptance and honest release boundary

- Software E2E: Godot 4.4.1 native import + browser camera/control/lesson matrix + original screenshot review + full ZIP/WASM/PCK + rollback test **must all pass**.
- Device test: run two independent ECO and HERO samples, preferably on multiple Android hardware tiers, with warm/cold load and multiple orientations; verify all 8 controls by hand.
- iPhone: separate real Safari/Web Inspector session is required; Chrome CDP data cannot certify it.
- Physical performance thresholds: set before observing results (e.g. minimum readability, acceptable lag, no unsafe interlock skips). Explain metric type and device; do not invent 60 FPS, temperature or battery readings.
- **Production W11 must remain unchanged** until an entirely new validated game release is deliberately promoted through the protected SHA-pinned production pipeline.
- When hardware is unavailable, close the SOFTWARE QA only; leave physical acceptance as NOT MEASURED.
