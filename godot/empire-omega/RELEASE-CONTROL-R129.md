# EMPIRE Ω — R129 engineered 3D sports coupe and release gating

This feature is a **real playable Godot 4.4.1 game source change**, not an image or concept render.

## B1 — authentic authored car design (this PR)

Actual R128 desktop Godot screenshot (960×540, captured from a real Chromium WebGL run) was inspected. The player's coupe is visible up close; the original sloped windscreen was a single uniformly tinted quad, and front splitter a simple primitive box. These now have real nonplanar detail in original editable source:

- Keep all **four** original named car windows, but turn each one into a ONE-surface **five-quad ceramic frit/glass mesh** (30 vertices/10 triangles each). The original windshield adds **two true 3D wiper blade quads** (42 vertices/14 triangles). No extra MeshInstance3D, physics body, collision shape or light. All glass is rough tinted native physically shaded non-emissive PBR glass; the dark ceramic border uses vertex tones, and four redundant glass shadow passes are disabled to help the WebGL mobile budget.
- Replace only the **existing** `FrontSplitter` primitive BoxMesh with a sculpted single-surface **eight-element, 96-triangle machined aero lip** with sun-lit gunmetal vs charcoal duct colors and dimensional side winglets. Retain all original box node names so real garage paint tests, suspension/steering and runtime visuals continue working.
- Continue using the same original long-body curved `FlowBody`, `AerodynamicGreenhouse`, all **four** independent steering/spinning wheels and R39 rotor/bolt/tread batches, original headlight cast range, braking lights, wheel raycasts, physical collisions and all 40 missions. No new images, textures, downloads, third-party vehicle models or 3D library dependencies.

These changes are deliberately bounded, not claimed to be AAA/photogrammetric realism. The player car remains an original stylized procedural 3D model.

## B2 — mandatory original game acceptance (fail closed)

1. The new `v103_r129_coupe_3d_glass_aero.gd` must compile in actual Godot **4.4.1** and inspect the original live source nodes: four glass surfaces with exactly 30/42 vertices, material normals/vertex colors/physical clearcoat, front and rear visible faces, original 96-triangle sculpted eight-mass front body, 4 actual rolling wheels, painted curved body, original brakes, exactly one `CollisionShape3D` and unchanged GameState.
2. The independent targeted workflow `.github/workflows/omega-r129-real-coupe-pbr-glazing-qa.yml` must pass original vehicle movement, four-wheel contacts, brake grips, headlight/night tests, R39 wheel art, R126 AI traffic, R127 drive/save continuity, R128 command accessibility and native R129; then actually export original WebAssembly/PCK and capture pixels in **real Chromium** (do not call a generated image a render). All CI checkouts must pin the original source SHA, not a synthetic PR merge SHA.
3. Original `scripts/omega-r109-release-sentinel.py` must SHA-lock **22 critical original game source scripts, 39 original native Godot test suites, and 3 actual pinned CC0 photographic roadway material assets**. The full exact-head R109 release workflow must pass native 39-suite suite, four genuine Chromium 3D/390px-phone/F9/host rAF tests, upload original playable WASM/PCK + screenshot evidence, and produce independent source+binary provenance.
4. After merging to the **unpublished** R90 staging branch, re-run these exact same checks on the resulting combined branch commit SHA. Only claim integrated engineering acceptance after all checks pass and save the exact artifacts and run URLs to draft PR #500. Any failures must be investigated from real runner job logs; never weaken checks to get a green badge.

## B3 — artistic and physical device release hold

The true R128 screenshot still shows a low-poly procedural city, especially the large pale buildings, silhouetted foliage and small city text. The change to a windscreen/nose helps the existing playable asset but does **not** establish parity with the user's two approved photoreal AAA/cinematic reference images. R128's existing 36-device-trial PC/Android/iPhone physical-device gate remains unfulfilled on actual physical hardware (software Mesa/SwiftShader Chromium is **not** a target GPU FPS measurement). Real user/reference visual sign-off, 40 mission human-play acceptance and an actual rollback rehearsal remain mandatory.

**Never merge production PR #500 to master or deploy SSH/VPS** until those separate evidence gates pass. Master `public/games/omega-3d-preview/release.json` preserves R87 `source_commit=43ae041e8df52418ca74c02405de9c196b59bd37` and must remain unchanged.
