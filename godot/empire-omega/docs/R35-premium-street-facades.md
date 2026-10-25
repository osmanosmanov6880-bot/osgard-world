# EMPIRE Ω — R35: real street-level facade depth (WebGL-friendly)

## What changes in the playable world
The R34 camera exposed that many building elevations are flat slabs. R35
adds **original solid 3D balcony geometry** to selected street-facing
upper floors: stone ledges, dark parapet guards, metallic top rails and two
corner stanchions. Layout uses the *same face* as the current real storefront
and entrance, so the geometry looks out on a road rather than a courtyard.

There are no stock images, fake CSS backgrounds or separately instantiated
objects per facade. Four shared Godot MultiMeshes render many balconies with
per-instance colour. Geometry is visual only: no new collision bodies, navigation
changes, missions, traffic impacts or pricing/economy changes.

Each eligible building receives at most three balconies, no more than
five physical parts each. Instance limits prevent unbounded memory and draw
calls. LOW quality hides the entire collection, STANDARD hides the finest
metal posts, CINEMATIC enables all four GPU batches.

## Boundaries, not AAA claims
This improves 3D shape and surface depth but does not create film-grade
city scans, high-poly characters, a ray-traced reflection system, cloth
simulation or calibrated car dynamics. These require licensed or original
authoring assets, device-performance measurement and more implementation.

## Acceptance plan
1. Native v57 R35 verifies real transform placement, facade orientation,
   four MultiMeshes, bounded instances, non-collision contract and quality tiers.
2. Previous city material/window/entrance tests and R33 wet four-wheel
   physics plus R34 camera remain green.
3. Actual Godot WebAssembly/PCK and four desktop/phone Chromium frames
   remain mandatory before merge.
4. Merge only after all relevant CI checks and release-readiness pass.
   Verify public SHA-256 7/7 and actual drive after publication.
5. Record Android Chrome and iOS Safari FPS/heat only on physical devices.
