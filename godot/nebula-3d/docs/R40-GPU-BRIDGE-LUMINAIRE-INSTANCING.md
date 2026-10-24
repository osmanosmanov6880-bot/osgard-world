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
