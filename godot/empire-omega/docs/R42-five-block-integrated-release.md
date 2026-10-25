# EMPIRE Ω R42 — five-block native Godot integration and safe release

R42 is a release candidate only. It integrates R36, R38, R39, R41 and experimental R24/R40 on verified R37. Never publish before exact-source acceptance.

## Actual code
- **R36:** opt-in 2-second warmup, 20-second Godot runtime frame sampling and p50/p95/p99 export. Device and SHA are **not** hardware-attested.
- **R38:** 81 intersections with 3D curbs, storm grates, bollards and end caps condensed into four instanced GPU batches.
- **R39:** PBR wheel rotors, bolts and tyre relief attached to animated wheel rigs, with quality tiers.
- **R41:** predictive relative-velocity pedestrian yielding to approaching vehicles.
- **R24/R40:** independent RigidBody3D four-spring physics calibration lab, not wired into playable CharacterBody3D driving.

## Fail-closed promotion contract
1. The real Godot main script and each gameplay, road, car, AI, telemetry, and lab script must load in the same integration tree. Run native feature tests, not only source assertions.
2. Export authentic Godot 4.4.1 WASM/PCK and capture **real** pixels at 1366x768, 390x844, 320x568, 844x390. Test each viewport in a separate Chromium worker to avoid GPU context leakage. Desktop must open the real government panel via Tab.
3. Never count a green CI candidate as a published release. After merge, require exact source SHA, seven public SHA-256 checks, live WebGL driving, recovery and rollback.
4. SwiftShader cannot certify physical Android/iPhone FPS, P95, heat, GPU 1% low or full rigidbody driving. Demand three native/user-device 20-second measurements, exact source, unedited video, observed p50/p95, power/thermals.
5. Preserve original saves, city economy, mobile controls and gameplay; do not silently activate the laboratory spring solver.

Keep the individual feature PRs until the integrated candidate and all its contracts pass.
