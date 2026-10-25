# EMPIRE Ω — R90/R104 release-control contract (26 October 2026)

**Source of truth:** `godot/empire-omega` (original Godot 4.4.1 GL Compatibility), not a mock website, image, generated JPEG layout, Three.js mock-up or unrelated OSGARD subproject.

**Safe release rule:** R90 is an **unpublished candidate** in branch `feat/omega-r90-aaa-reference-first-slice-20261026`, PR #500 against `master`. The existing public **R87** runtime is not to be overwritten without green acceptance of the fully integrated, exact commit and explicit human visual sign-off. There are no "100% AAA" or photorealism claims until real Godot screenshot review supports them.

## Integration ledger — read GitHub Actions live, never assume PASS

| Feature | Authority | Evidence / critical invariant |
|---|---|---|
| R87 | existing public baseline | working missions, saved game, city governance |
| R90 | actual Godot dashboard | a new live `SubViewport` shares the authoritative `World3D`; Tab opens real controls |
| R91 | real skyline facade/roof geometry | actual instancing, no stale-window collisions |
| R92 | projected district selection | projected with real 3D command-camera transforms, not invented 2D pins |
| R93/R96 | real energy, water, food, roads, stability | source-based `GameState` + forecast; no fabricated values |
| R95 | real city massing | bounded height, original roads and building footprints |
| R97 | graphite/champagne-brass hierarchy | city before finance tiles; keep genuine navigation and mobile fallback |
| R98 | PBR 3D facade fins | one bounded MultiMesh, no collision, no RNG change |
| R99 | intended wider true 3D command camera | 1x viewport resolution and functional top-right close button |
| R101 | reviewed photographic road assets | Poly Haven CC0, exactly three 1024x1024 JPEG maps + per-file SHA256 lock |
| R102 | graphics quality tiers | low unchanged, standard albedo, cinematic three PBR maps; only if originals available |
| R103 | native legacy R32 fix | city background scrim **0.36**, unchanged legacy 0.40 maximum |

The integration ledger is descriptive, **not an assertion that every PR above has passed or merged**. For each PR, inspect the current head SHA and GitHub Actions result before promoting code.

## Hard gates before ANY R90 → master promotion

1. **Commit identity:** merge only tested features; record exact candidate HEAD SHA and an immutable run/commit link. Never use the label "PASS" from a different SHA.
2. **Strict importer:** `scripts/omega-strict-godot-import.sh godot/empire-omega` must succeed; Godot can return code 0 even for syntax errors, so the script rejects parsed warnings.
3. **Real native regression:** `v29_responsive_layout`, `v54_r32_cinematic_cabinet_wet_grip`, `v76_r87_honest_mission_navigation`, `v78_r90_reference_fidelity`, `v79_r91_original_architecture`, `v80_r92_real_district_projection`, `v81_r93_live_civic_metrics`, `v82_r95_city_massing`, `v83_r97_cinematic_command_hierarchy`, `v84_r98_facade_geometry`, `v85_r99_command_visual_geometry` and `v86_r102_real_asphalt_quality` all present and passing on the final integrated branch.
4. **WebGL evidence:** actual Godot 4.4.1 `.wasm`, `.pck` and `index.html` built from candidate SHA; original Chromium real before/after Tab screenshot, no canvas crashes or JS errors. A successful Godot parser alone is NOT a visual acceptance.
5. **Asset provenance:** `scripts/r90_cc0_texture_pack.py verify` must pass if the 3 road maps are embedded; licence `CC0`, source `https://polyhaven.com/a/aerial_asphalt_01`. Missing binaries must be surfaced as a **visual quality gap**, even when the renderer safely falls back.
6. **Gameplay truth:** 40 chapter progression, save/load, economy/mission/council/district buttons and vehicle interactions cannot be silently replaced by decorative inactive UI.
7. **Accessibility and layout:** no clipped buttons or unreadable fonts at 1366x768 and 1920x1080; preserve 390x844 portrait fallback; keyboard Tab, close, section navigation, touch controls and reduced-motion preference need real verification.
8. **Performance:** collect real p50/p95 frame-time, native phone responsiveness and WebGL export size. Do not invent an FPS figure. Low quality must bypass optional R98 facades and second live 3D render pass.
9. **Art-direction sign-off:** compare actual game screenshot side-by-side with the user's approved two AAA references. Record evident differences honestly (materials, geometry, density, shadows, composition, typography). Current procedural buildings and cosmetics are NOT photogrammetric or film-grade by assertion.
10. **Rollback:** preserve public R87 bytes, record deployed commit and artifact hash before any master merge. If master deployment or real users regress, revert to the known public R87 artifacts; do not overwrite source commits or force-push.

## Reproducible local original-engine smoke (when Godot and dependencies are installed)

```bash
python3 godot/empire-omega/tools/generate_audio.py
python3 godot/empire-omega/tools/generate_patrol_audio.py
bash scripts/omega-strict-godot-import.sh godot/empire-omega
godot --headless --path godot/empire-omega --script res://tests/v54_r32_cinematic_cabinet_wet_grip.gd
godot --headless --path godot/empire-omega --script res://tests/v83_r97_cinematic_command_hierarchy.gd
godot --headless --path godot/empire-omega --script res://tests/v84_r98_facade_geometry.gd
```

Official CI export flows are `.github/workflows/omega-r90-reference-fidelity-qa.yml`, `.github/workflows/omega-r97-cinematic-command-qa.yml`, and `.github/workflows/omega-godot-web.yml`. A merge to master invokes `omega-godot-web.yml` and can automatically publish the exported runtime and trigger `deploy-frontend.yml`: treat **merging PR #500 as production-affecting**. Keep it a draft until sign-off.

## Open questions requiring evidence, not another concept render

- Were the reviewed 3 original road JPEGs actually committed to the candidate? A passing network asset-fetch CI **does not** mean that the game already embeds them.
- Has R99 expanded the live atlas in a *new* Chromium capture without clipping or excessive GPU use?
- Did R102 compile with all 3 quality tiers and change real visible road appearance only when verified binaries exist?
- Can a tester understand a first mission and economic action without coaching and then successfully return to the world?

## Current policy

Do not create more proposed reference images. Prioritize actual source, original renderer, genuine playable interactions, measured screenshots and explicit release evidence. **No unattended production deployment while gates are incomplete.**
