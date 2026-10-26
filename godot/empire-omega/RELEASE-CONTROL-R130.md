# EMPIRE Ω R130 — player-first-screen actual Godot fluted portico

**Status:** authored original Godot 4.4.1 candidate in a separate, NON-production branch; do not mistake passing engine tests for the original user's two approved photoreal reference images.

## B2: source geometry in the actual first-view city

Reviewed genuine original rendered R128 first-screen Chromium image (960×540). Six pale near-camera cylinders dominate the civic entry view; the original R28 `CivicStonePillars` shared `CylinderMesh` uses only 14 radial sectors and physically shallow capitals were plain boxes.

R130 directly replaces ONLY these two shared meshes in `horizon_civic_gateway.gd`:
- A **real original 12-flute 48-radial-sector limestone shaft**, tapered and slightly swollen (entasis) over eight axial sections, top/bottom discs. **864 genuine source triangles per shaft × six original instances = 5,184 triangles**, in the SAME `CivicStonePillars` MultiMesh GPU batch.
- **Four physical moulding strata per capital**, 48 source triangles per capital across six original instances; same `CivicCapitals` GPU batch. Four quiet mineral color tones multiply the same original per-column palette, with original 64px triplanar PBR limestone/normal maps.
- All six original 10.8m column world transforms `x=-10+4*i, y=5.4, z=14.0` (relative to the original civic gateway) and six capital origins at y=10.93 remain identical. Live cityhall WorldBuilder still spawns the gateway at `(-130,0,-130)`, original static collision body untouched.
- All seven original gateway draw batches, 58 original physical instances, 20 existing near glass/metal/window panels, ground roads, actual body collision, player/traffic/game economy and save all preserved. LOW still hides all decorative gateway batches; CINEMATIC shows them. No new assets, licensed third-party dependency, mesh nodes, coliders, weatherlights or arbitrary GPU shader allocation.

## Acceptance gates

1. Existing `v52_civic_pbr_gateway.gd` is STRONGER, now verifies actual 864-triangle real sculpture and 48-triangle physical capitals instead of the old trivial CylinderMesh radius claim. The added native `v104_r130_fluted_civic_stone.gd` checks real 3D normals, physical flute groove >2cm, bounded local dimensions, four real mineral tone courses, all six exact original instance transforms, physically shaded triplanar source, existing original collision, 58 instances/seven draw batches, LOW/CINEMATIC visibility and identical GameState.
2. Independent `omega-r130-original-fluted-civic-qa.yml` must pin the ORIGINAL immutable PR HEAD SHA, run actual strict Godot 4.4.1 import and R28/R127/R128 regressions, export actual HTML5 WebAssembly/PCK, render actual 960×540 Godot in Chromium via the same source and archive original screenshots. No static image, synthetic Godot replacement or SSH step.
3. After the independent target full PASS, integrate with the coexisting separate R129 authored sports-car work and run a **full combined-head R131** campaign: source SHA-lock both `horizon_civic_gateway.gd` and `horizon_vehicle_art.gd`, mandatory original R129 v103 AND R130 v104+old R28 v52 native tests, four real Chromium desktop+phone+F9+frame telemetry tests, uploaded runnable WASM/PCK and exact-source provenance. Neither two individually-green PR heads nor a synthetic GitHub merge-preview constitute proof of the final combined code.
4. Before **any** master/public release, independently compare original real game pixels to the two approved user reference images, capture real desktop/Android/iPhone physical GPU p95/p99 and user playthrough of all missions, protect original R87 WASM/PCK and verify isolated rollback. Current 3D remains stylized procedural art. **Master draft PR #500 / live SSH publication remain HARD HOLD.**

This document records factual engineering source and necessary future evidence without a fictitious claim of 8K/AAA completion.
