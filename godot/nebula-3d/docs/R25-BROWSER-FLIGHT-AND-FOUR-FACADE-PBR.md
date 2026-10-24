# NEBULA R25 — 3D facades and **actual browser flight** acceptance

This release is a source-code upgrade to the **existing Godot 4.7.2 WebGL game** on OSGARD, not a generated image, standalone mockup or replacement game.

## The control problem that native testing missed

R21–R24 proved that a Godot headless scene can move its ship via physical keyboard events and the START FLIGHT button. They did **not** prove the live browser's WASM runtime receives those events.

R25 adds a compact, read-only `window.__nebulaPilotTelemetry` object **written by real Godot GDScript in the actual browser build**, 5 times per second. It contains only public gameplay diagnostics: world coordinates, engine velocity, keyboard input bits, throttle, heading, mission distance, paused-control state and sample number. It contains **no identity, purchases, account data, Stripe keys or inventory**. The bridge is absent in native Godot.

New `tests/browser_flight_r25.mjs` drives a real local export with Chromium:
1. Waits for a real Godot physics telemetry sample, not merely a visible HTML canvas.
2. Holds the actual W key; requires the browser key bit, nonzero velocity and **>3.5 m real in-world ship movement**.
3. Releases W and checks that the input bit is cleared.
4. Clicks **the actual Godot cockpit button**, not an injected gameplay command.
5. Requires cruise mode, actual craft rotation toward the off-axis first mission beacon and **>2 m decrease in objective distance**.
6. Clicks again and proves cruise can be stopped.
7. Saves `r25-browser-qa/flight.json` as an audit trail, with failed phases and last physical telemetry.

A dedicated GitHub Actions workflow runs this test after a successful native master-branch build; it does not confuse software SwiftShader with a physical GPU benchmark. The existing 720p/1080p visual-capture workflow remains separate. If software Chromium cannot initialize Godot, the browser check must fail/inconclusive, **not be reported as passing**.

## Real visible graphic upgrade, still compatible with phones

R22 created 18 high-detail towers, but added physically modeled lit/dark windows **on just one facade**. The other three building sides remained flat slabs when the player flew around them.

R25 adds correctly oriented **front, back and both side facade windows** for every floor of all 18 hero towers:

- **11,064 individual 3D window instances**, up from the earlier 3,227.
- **7,837 additional back and side windows**.
- **1,844 separately laid-out facade/floor groups**.
- Retains just **three GPU MultiMesh draw batches** for dark, amber/warm and cool glass. Lighting uses existing cached materials and R20 baked atlas on tower cores.
- No added per-window real-time lights, no extra physics for windows. Existing 18 tower colliders, 3 skybridges, 16 moving aircraft, R20 PBR maps, ten missions and saved purchases remain.
- Geometry is a functional authored scene in Godot; it is not photo-realistic purchased scanned assets, and does **not** establish AAA visual parity with the approved image.

## Gate and verification

- Source guard checks both real browser-test code and in-game state bridge.
- Native runtime checks the exact 11,064 instances and remaining physical structures.
- Godot 4.7.2 editor parse, smoke scene and WebAssembly export required.
- Independent Chromium flight check follows successful master export.
- Production deploy requires isolated SSH upload + checksum confirmation + Nginx activation.
- Real device performance still requires F7/F9/F10 and physical Android/iOS controls.

No Stripe configuration is changed.
