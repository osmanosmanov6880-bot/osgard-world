# LAST FRONTIER W80 — ACTUAL mobile immersive game usability and viewport fit

**28 October 2026 • Godot 4.4.1 • draft, no production release.**

**Verified exact baseline:** W79 source commit `8804d2fdcd28c8a4f6a606e9928f68f403c12617`, [3/3 original Godot native + genuine WebGL browser + original source PASS](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40747805564).

## Found in true source-built 390×844 Chromium screenshot

W79 is a fully software-playable five-stage original mobile mission. Inspecting the actual original mobile screenshot showed the previous W78 controller still had eight buttons arranged in **one horizontal row** wider than the actual inset 3D stage. Rightmost G and E controls extended beyond the right-hand world frame into the parent page; this is a serious real usability and cognitive-load defect, not a theoretical art-direction preference. A generated picture would never certify its repair.

## Real engine fixes in source

1. **Real W80 4×2 native physical controls**: replace original `HBoxContainer` for the eight true W70/W73 in-world movement/eye/G/E buttons with `GridContainer(columns=4)`. Row one: A/W/S/D physical walking. Row two: look left/right, aimed G and physical E. All are in-game Godot Button nodes driving the original `CharacterBody3D.move_and_slide`, Camera3D, W73 real RayCast and actual W71 inspection. Each native 48px-high target stays in the original inset world stage. At 320px controls use minimum width 32px; at 390px minimum 48px. No fake mobile controls or CSS overlay.
2. **Context deck separated from movement**: relocate the original W79 complete five-phase source command panel to the band immediately ABOVE the 4×2 thumb grid; actual 5px+ physical gap prevents taps on one deck from intercepting the other. It continues to operate genuine valve/relay/sync, the 12 original W63 game decisions, original W73 secure offline save/load and authentic victory/restart.
3. **Less chrome, more live 3D**: after player starts true first-person original mission, redundant top-level Play Now button hides until exit; the long 3D camera label becomes one concise bilingual source-aware line; repeated below-world objective hides because the active in-world mission deck already shows it. True original Godot 3D stage height increases to **65% of root mobile viewport** (390×844 -> 548.6px, 320×700 -> 455px). All original user input, sound, keyboard, gamepad, checkpoints and escape actions remain.
4. **Full bilingual accessibility**: 390 and 320 real source-driven responsive views with text width clipping, 48px button heights, reduced-motion and ECO source settings unaffected; desktop 768 and 1366 automatically hide both touchscreen decks.

## Not a mocked certification

- W80 native `test_w80_mobile_stage_layout.gd` constructs original `Main.tscn`, starts the real W79 mission, tests entire Godot GUI geometry for **all eight buttons** inside the actual inset stage and no overlap with original contextual mission dock at 390×844 and 320×700, checks 768/1366 desktop hide and source-aware header, actual 22-frame original physical W70 walk, release safety, EN label and unchanged original incident history.
- W80 Chromium `ci/w80_browser_mobile_layout.py` launches the **actual original compiled Godot WASM** at 390×844 and 320×700, reads all eight native Control rectangles from original source-exported accessibility bridge and validates their placement **inside real stage rectangle**, proper button heights, 4x2 geometry and action deck spacing. Physically holds W via original in-world button, verifies CharacterBody moves, clicks an out-of-range W79 valve and checks original source rejects it, renders RU/EN and restores all controls via Tab. **Six original unmodified PNGs** + exact source SHA and SHA-256, plus six full W79 original WebGL browser regression captures.
- All W63 original game rules, W70 physics, W71 mission, W72 physical field logic, W73 raycast/checkpoint, W74 controller/graphics, W77 real physical shutter, W78 original complete mobile controls semantics, W79 five-phase game validation tests and original source metrics are protected unchanged except three necessary interface composition files. CI hard source gate enumerates permitted changes.

**Release limitations**: No physical iOS/Android phone testing, commercial GPU 60fps validation, independent original professional AAA art/animation assets, independent human 10–15 minute playtests or trademark clearance. Software PASS ≠ AAA commercial release. Keep draft unmerged; W75 release evidence audit still requires real measurements, actual human expert signoffs and explicit publisher GO.
