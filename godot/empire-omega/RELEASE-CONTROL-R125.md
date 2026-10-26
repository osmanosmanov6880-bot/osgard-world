# EMPIRE Ω R125 — safe current-source command-city aperture

**Status:** R125 engineering candidate / DRAFT PR #549. **Not production. Not AAA visual acceptance.**

## Immutable ancestry (2026-10-26)

- R90 destination of #549: `d81ec92923fa5707f802c63d9ee54e5627e43b49`, #500 remains draft to `master`. R123 #546 and R124 #547 already merged into that exact source.
- Baseline exact-source R109 CI: [run 40285807970](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40285807970) — native, real Chromium and provenance success on the R90 SHA only. Art [40285807273](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40285807273) and original R124 [40285807403](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40285807403) are also success on **that previous SHA**. These cannot attest to R125.
- Original public R87 `public/games/omega-3d-preview/release.json` remains `source_commit: 43ae041e8df52418ca74c02405de9c196b59bd37`; original wasm `e4a43dbae28662b2a68f6136857a94db6695430901515800b9883f6327cb7116` and pck `c34d9b717b024bcec43239032d259229181568284186482ecfcd0f28e580fd4e` stay untouched.

## Exact scope

1. Keep the original Godot 4.4.1 governance UI, all seven real navigation tabs, financial authority, pointer interception, same in-world `SubViewport`, original source assets, original 3D cameras and interactions. Preserve `master` and R87.
2. Wide desktop (>=1200 x >=680) limits command width with `command_center_frame` to leave a real street-camera region at right. The original native full-window dimming becomes 0.18 alpha only for wide desktop; smaller displays retain the existing 0.36 alpha modal.
3. Native `v99_r125_command_city_aperture.gd` checks three real desktop layouts, original HUD panel offsets, live-screen aperture, compact mobile contrast, keyboard/button integrity and *unmodified GameState*.
4. The unchanged strict R109 exact source workflow now **adds**, rather than replaces, suite #32. All original **31 Godot suites** and **4 genuine Chromium WebGL** tests remain mandatory. The `omega-r109-release-sentinel.py` must SHA-256 fingerprint all 17 original scripts, all suite sources (now 32), the three original CC0 binary maps, the original source SHA and real exported HTML/WASM/PCK. Preserve playable candidate, renderer screenshots and signed provenance artifact for the **exact R125 HEAD**.
5. After optional separate #549 integration into R90 (only if green), run the same 32 native + four Chromium tests on the **actual merged R90 branch SHA** and record artifact links in draft #500; no synthetic merge result counts as a release pass.

## Hard stops

- No new image generation, fake frame, changes to physics/saves/mission rewards, weaker CI thresholds, missing/or expired SHA evidence or release publication.
- A compilation success is *ENGINEERING PARTIAL*; a full exact-source pass requires all native, all authentic Chromium and all source/CC0/WASM/PCK SHA artifacts with current immutable SHA.
- The city remains visibly stylized; no reference-matched photoreal AAA art signoff and no measured target-device GPU FPS. **AAA ART HOLD**, **PRODUCTION HOLD**, explicit independent rollback validation required before a new publication decision.
