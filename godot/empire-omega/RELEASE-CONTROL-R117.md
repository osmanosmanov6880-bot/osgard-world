# EMPIRE Ω — R117 integrated original Godot release-control contract

**Status:** unpublished candidate, **not** the public game, not an AAA art sign-off.
**Engine:** original Godot 4.4.1 GL Compatibility, not mocked Canvas/PNG.
**Authoritative code:** `godot/empire-omega`. **Release CI:** `.github/workflows/omega-r109-final-candidate-evidence.yml`.
**Main guarded release PR:** [#500](https://github.com/osmanosmanov6880-bot/osgard-world/pull/500) — keep **DRAFT** until an actual source/binary/visual acceptance.

## Immutable baseline / rollback

- Existing public `master` Godot preview `public/games/omega-3d-preview/release.json` records original R87 `source_commit`: `43ae041e8df52418ca74c02405de9c196b59bd37`. Its recorded `index.wasm` SHA-256 is `e4a43dbae28662b2a68f6136857a94db6695430901515800b9883f6327cb7116`; its `index.pck` SHA-256 is `c34d9b717b024bcec43239032d259229181568284186482ecfcd0f28e580fd4e`.
- **Never** delete/rewrite that recorded executable or move master before all gates below pass. Keep the existing real R87 source/binaries reproducibly retrievable.
- Do not treat a GitHub PR title, mock illustration, renderer screenshot alone, or job queued/in progress as a verified release.

## Integrated functionality under test

| Feature | Original source / proof required |
| --- | --- |
| R87 gameplay and honest real missions | Actual original `v76_r87_honest_mission_navigation.gd` and predecessor 40-mission transaction tests |
| R90/R97 cabinet and real city authority | One actual `World3D` / live `SubViewport`, native seven-tab original governance interface |
| R91/R114 rooftop architecture | Same original **72** tower instances, 2 architectural batches, real 48-triangle PBR penthouse meshes |
| R106/R107 CC0 road PBR | Three actually committed 1K photographic JPGs SHA-256 verified against `assets/r90/provenance.json` |
| R108 mountain horizon | A real native Godot continuous procedural indexed mountain mesh, no road/physics mutation |
| R111 road rain/clear identity | Correct asphalt vs concrete after photographic UV scale change |
| R112 projected districts | Actual `Camera3D` updates four selectable original city region labels |
| R115 original focus | Reversible real HUD sidebars and six city stats, keyboard **F9**, current **Godot-container-owned 1:1** viewport size, reproject pins on native resize, no extra world, control always above 540px fold |
| R116 structural PBR | **72** original tower transforms, one original `MultiMesh` draw batch, seven real sculpted building body masses / **84 triangles** per tower, shared cached albedo+normal+roughness, original windows and roofs retained |

## Mandatory exact-head CI gate

1. GitHub Actions checks out **the merge candidate actually tested**, not another PR's previous SHA. Original `scripts/omega-r109-release-sentinel.py` must fail closed when any source, test or licensed binary is absent or tampered with. Expected count: **22** original native suite files plus explicit original game/render architecture source SHA-256 locks.
2. Strict unmodified **Godot 4.4.1** import with warnings/errors fatal. Execute all 22 actual engine suites, including `v92_r115_true_world_focus` and `v93_r116_architectural_tower_body`. All suites must exit **0**; never replace a real engine regression by scanning text.
3. Build a **new actual executable WebGL** `index.html` + `index.pck` + `index.wasm` from that same source. Run authentic Chromium with native canvas/WASM: (a) city drive-to-Tab dashboard, (b) real portrait `390×844` touch frame, (c) reported **Chromium host rAF p50/p95** only (not hardware GPU FPS), (d) F9 focus and restore actual live 3D with **three captured PNGs** and real pixel differences. No renderer crashes or JS page exceptions. **Four of four tests must pass**.
4. Upload all original exported runtime files as an executable GitHub artifact, setting `include-hidden-files: true` for the one scoped `.build-web` folder; attach actual screencaptures, WASM/PCK hashes, Git checkout SHA and source provenance manifest.
5. After PR merges into the long-lived **R90 staging branch**, rerun the same source+binary+browser suite from that *exact integrated head*. Previous passed PR merge previews are **not** automatically evidence for a newly changed mainline SHA. Archive artifacts and links as part of the release record.

## Mandatory human and device art signoff before public deploy

- Compare actual **Godot Chromium frames**, not a generated image, against the two previously approved AAA/reference screenshots.
- Confirm visual hierarchy, non-cartoon materials, measured typography and spacing, roads/buildings/car/foliage, four districts, mission HUD, contrast and interactions at desktop and mobile.
- Measure actual target hardware graphics smoothness independently. **Do not** claim 60 FPS from software-Mesa CI requestAnimationFrame telemetry.
- Current original game is a **stylized procedural 3D city** and has **not** been certified as photoreal AAA. A passing compiler, 22 native suites and four screenshots cannot establish cinematic art parity.
- Only after these gates and an independently approved rollback procedure may a separate production publish PR be considered. The R117 QA workflow **contains no deployment step** and must stay that way.

## Status and evidence reference

- **R113** [original fully successful run 40249211500](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40249211500): 20 native suites, 3/3 authentic Chromium, SHA-locked CC0, downloadable executable WebGL artifact 12620049962 and original provenance artifact 12620440877.
- **R116** [original fully successful run 40250185061](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40250185061): 278/278 structural native assertions and authentic WebGL renderer proof; merge #536.
- **R117** [candidate PR #537](https://github.com/osmanosmanov6880-bot/osgard-world/pull/537): **pending exact-head CI** as of source authoring. Never set PASS until native + Chromium + provenance results confirm it.

