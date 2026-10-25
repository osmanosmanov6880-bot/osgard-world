# NEBULA R40 candidate — batched bridge luminaires

## What changed
- In R22 Aurora's three real suspended flightways, 16 emissive cuboid
  fixtures on each of two bridge rails are unchanged geometrically.
- Former draw-node representation: 3 bridges x 2 rails x 16 independent
  MeshInstance3D nodes = **96 mesh nodes**.
- Candidate draw representation: **three MultiMeshInstance3D nodes**,
  each retaining **32 3D fixture instances** and using the existing
  emissive material.
- World transforms preserve the old bridge-local geometry; collisions,
  bridge load-bearing nodes, route and mission logic remain unmodified.
- Per-bridge batching avoids global bounds and retains LOD visibility
  group control.

## What this does and does not prove
This is a **code-level draw-submission reduction** (96 -> 3 candidates),
not a measured **93 GPU draw-call** reduction, and not a claim of higher
FPS on any Android/iPhone.
Native Godot smoke must assert all 96 instances and 3 bridges, then
the full WebAssembly flight/touch tests and real R39 before/after
measurements must confirm visual equivalence and device performance.

## Acceptance
1. Godot 4.7.2 project imports cleanly; real native runtime smoke passes.
2. Real Chromium WebAssembly flight and touch input remain functional.
3. Capture visual reference with trustworthy hardware renderer; compare
   all three bridges for no missing emissive fixtures, no incorrect scale.
4. On each physical phone, run R39 control and R40 candidate under the
   same resolution, graphics profile, route and orientation.
5. Only call R40 faster on device when repeated measurements improve
   median FPS / P95 without functional or visual regression.
6. If measurements regress, do not deploy this PR or revert it.

No payment, account, server or data-collection change.

## Candidate build delivery (for real-device testing)
On PR #342, after its latest CI completes successfully, download the
`nebula-r40-on-device-candidate` GitHub Actions artifact from the
`REMIX NEBULA 3D native Web release` run. The archive contains the
actual exported `index.html`, `index.js`, `index.wasm`, `index.pck`
and related assets. Keep those files together in one directory.

Serve the package over HTTP(S) from a testing computer accessible to the
physical phone (a properly configured local network or temporary controlled
HTTPS testing host). Do not open the files as `file://` URLs. On a trusted
computer with Python installed, from the unpacked asset directory:

```sh
python3 -m http.server 8765 --bind 0.0.0.0
```

Connect only on a trusted/private network, restrict firewall access, and
avoid exposing the test server to the internet without HTTPS/authentication.
Use the test computer's LAN address and port in the phone browser. No
production payment or server activation is involved in this artifact step.
Baseline control is the published R38 game; experimental candidate is the
artifact. Match viewport, route, quality profile and device; collect three
20-second JSON reports per condition. Run R39 viewer locally against both
sets, recording baseline/candidate labels separately.

## R40 reporter provenance
This candidate's real Godot benchmark JSON adds
`build_variant: "NEBULA_R40_BRIDGE_BATCH_3X32"`. R38 baseline JSON has
no `build_variant`. The R40 A/B viewer should check this declared field and
reject accidental baseline/candidate mislabeling. The field is not signed and
cannot prove phone or runner identity; preserve original files and device logs.

## Exact geometry and physics parity
Native smoke additionally checks all 96 instance transforms against the
original R38 bridge-local positions (tolerance 0.001), exact unit-Box scaling
(1.6 x 0.10 x 0.85), and the 269 x 5.4 x 9.2 flightway collision shape
on each of three spans. These code-level invariants do not substitute for
visual inspection or physical hardware GPU timings.

## Headless geometry-test limitation
The expanded native test initially exposed an important false assumption: in
Godot launched with `--headless`, the dummy RenderingServer can report
`Transform3D.IDENTITY` for `MultiMesh.get_instance_transform()`, even after
valid calls to `set_instance_transform()`. It is not a physical 3D render.
R40 therefore stores an exact, in-memory copy of the **submitted** CPU
instance transforms and checks every lamp location/scale and bridge collision
against R38 on the native runner. The real browser tests separately verify
WebAssembly flight and controls. A true GPU screenshot and real-phone FPS A/B
remain independent human acceptance requirements.
