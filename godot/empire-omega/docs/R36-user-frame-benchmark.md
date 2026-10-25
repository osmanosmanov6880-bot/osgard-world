# EMPIRE Omega R36 - genuine user-initiated render-frame evidence

The existing R16 F3 panel shows a rolling p95, but has no downloadable
benchmark evidence. R36 adds two real Godot HUD controls: TEST 20S and EXPORT
JSON. On phones the native FPS quick-actions menu opens the same panel.

Actual game Node._process(delta) captures 2 seconds of warmup followed
by 20 seconds of render-frame timing, together with original Godot Performance
render draw-call counters. All data stays local; a completed capture can be
downloaded from Web or written to native user:// as JSON. The opt-in button
and export are real gameplay UI input; no third-party analytics requests.

Output includes valid sample counts, p50/p95/p99 frame milliseconds, mean
observed FPS, viewport size, effective graphics preset and renderer draws.
It expressly sets physical_hardware_attested=false, source_sha_verified=false
and device_model_verified=false. An original OS name is informative but not
hardware identity. A background tab aborts the run instead of substituting
inaccurate FPS, and the bounded array allows up to 300fps for 20s.

Native unit tests inject mock delta values ONLY to validate algorithm,
UI button signals and JSON contract; these cannot count as physical-phone
benchmarks. Full acceptance still requires a human on a real Android
Chrome and iPhone Safari, the matching public build SHA, three 20s runs,
recorded p50/p95, thermals, graphics preset and unedited video before a
30-FPS-mobile claim is justified. No FPS improvement can be assumed.

If an actual high-refresh renderer records more than the bounded 6000
samples during 20 seconds, the capture now explicitly reports
`sample-capacity-exceeded` and refuses to export a misleading undercounted
mean FPS. A 360 Hz simulation is a unit test of this safety rule, not
an actual 360 FPS hardware claim.
