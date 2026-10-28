# LAST FRONTIER — W84 REAL NATIVE MOBILE CONTROL STUDIO

Major original Godot 4.4.1 source release, in-game—not image generation.

## What actually works
W84 adds the **real user-controlled Godot mobile settings deck** to the same W80 full-bleed 3D scene, physically connected to the original W83 touch gesture controller and the same eight W78 Godot Button objects. The overlay is compact, dark obsidian/copper/cyan and mobile-readable.

### Original Camera3D sensitivity
Native player can tap **LOOK / ОБЗОР** to choose 0.55 / 0.85 / 1.15 / 1.50 real pointer gain. The setting is passed into the original `A7DualTouchLook.set_look_preferences()` and modifies the real `A7FirstPersonOperator.rotate_view()` input. Nothing redraws a 2D fake camera. Camera yaw and head pitch are the actual Godot W70 CharacterBody3D and Camera3D transformations.

### Actual vertical-axis inversion
An independent native tap changes real camera Y sign *before* the original W70 `rotate_view`. Godot head pitch truly reverses. It has no effect on walking, collision, raycast equipment, source game state or original A7 decisions.

### Source physical left-hand controls
The left-hand profile rearranges the **same eight W78 actual Godot buttons** inside its original `GridContainer`, with `move_child`. This changes their real on-screen positions but never changes W/A/S/D/G/E key mappings, never clones/duplicates the original buttons, and keeps the 4-column native grid in 320, 390 and landscape 844 viewports.

### Private persisted control comfort
Only three nonsensitive control values are written with native Godot `ConfigFile` to `user://last_frontier_native_touch_controls_v1.cfg`: gain index, invert-y and handedness. No network, account, ID, or game checkpoint authority. Native source tests cover save/reload and invalid values. Default/reset: gain 0.85, standard Y, right-hand buttons.

### Actual safe modal
Touch settings entry is top-left 44px-class and does not overlap original W80 top-right native MENU and RU/EN. On opening profile, original held W/A/S/D input is released, W83 source camera gestures are canceled + suspended, and W78/W79 original physical commands are hidden, preventing accidental hazard actions. Closing restores same actual source controls. Exiting full-bleed MENU or resizing ends obsolete input cleanly; no fake decisions or checkpoint rewards.

### Actual responsive native controls, not a concept screenshot
- 390×844 portrait: true source panel and world with 44px controls
- 320×700 narrow portrait: original 4-column mission and tuning controls fit
- 844×390 landscape: centered real source panel, W80 MENU stays reachable, preserves original 3D scene
- Desktop: touch-specific settings hidden automatically
- Real RU/EN captions and reset to original defaults
- No generated imagery, no replacement of original 3D stage, CharacterBody physics or W63–W83 mission rules

## Acceptance and production HOLD

Hard gate: exact source parent commit `0de8104918e7dc300998a258dd7599657bf33104`, **7 approved modified/new paths only**; all original W63–W82 protected game systems, W78 original physics buttons, W79 original mission, W80 original full-bleed, W82 compass, W83 physical touch core, W83 Chromium driver and original checkpoints remain protected except the specific W84 camera preference calls and screen wiring.

Native: **13 Godot 4.4.1 suites**, including W84 actual camera inverted-Y, 320/390/844 adaptive geometry, same CharacterBody, no source A7 score mutation, left-handed same native eight physical buttons, ConfigFile save/reload and panel input safety.

Browser: exact SHA genuine WASM/PCK + real original W83 CDP two-finger physics browser + original W81/W82 Chromium regression + new W84 real GUI clicks, original physical inverted camera drag, same original 3D body, 320/390/844 responsive and strict actual button sizes. **24 genuine screenshot frames** (7 W81 + 5 W82 + 6 W83 + 6 W84) SHA-256 validated per exact source commit; no source mutation through browser JS.

3/3 strict GitHub CI; no green claim until exact HEAD pass. DRAFT. No Android/iPhone physical phone certification, actual GPU frame stability, 10-15 minute external mission playthrough, professional AAA art/audio/animation QA, rights clearance, or public commercial release. Never merge automatically to master.

## Reproduction
From CI evidence use source SHA and its WebGL export, test logs, native game stage screenshots and JSON manifest. On real hardware validate sustained 10-minute two-finger controls, orientation, touch targets, safe areas, load/save, mobile memory and device power. If physical tests fail, release stays on HOLD.

## W84.1 — precise acceptance guard and export path correction
Initial [W84 CI #40775022650](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40775022650) failed the exact-source static gate due to a CI assertion checking a nonexistent variable spelling `original_core_commands_issued`, while the actual Godot module correctly declares `original_game_commands_issued`. Replaced the guard with the **real source symbol**, not a skipped guard. Also corrected the WebGL export's working directory to match the already proven original W83 source engine build: `cd w63-a7-cascade && godot --headless --path . --export-release Web build/web/index.html`. This prevents output-path confusion without changing original physics, game decisions or engine. Full native+browser QA still required.

## W84.2 — inherits fully accepted W83.8 original two-finger WebGL source
W83.8 [exact source run #40774347723](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40774347723) achieved **3/3 GitHub CI PASS**: 12 Godot native tests, original physics, true independent portrait+landscape Chromium two-touch sessions, correct CDP changed point release semantics, original W81/W82 full browser regressions and 18 SHA-bound live frames. W84.2 merges the **exact** W83.8 original browser CI/docs/runner blobs into W84 (no application logic rewrite) and pins this accepted source SHA `0de8104918e7dc300998a258dd7599657bf33104` as the parent of a true two-parent Git merge commit. The W84 source protector still demands that only the seven W84 native source/UI/test/doc/CI paths differ from this accepted W83.8 code. The new W84 user preferences are therefore layered on actually accepted physical two-finger software, not the superseded W83.7 temporary browser driver. Full W84 13 native + 24 SHA browser screenshot verification is still mandatory.
