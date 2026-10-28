# LAST FRONTIER — W83 ACTUAL INDEXED MULTITOUCH 3D GAME INPUT

**Engineering PR only.** Original source parent `239af2787e287da7674cf49e533f2dbc99bdc1cb` (W82 PASS, [actual Godot CI 40760928753](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40760928753)).

## Substantive original gameplay changes
The LIVE Godot 4.4.1 full-bleed WebGL scene now accepts a second distinct native screen finger for drag-to-look while the first remains held on one of the **original W78 physical walk buttons**, without rebuilding the 3D world, collision actor, original W63 A7 game, raycast or equipment. This is a genuine mobile-game interaction, not a browser illustration or a decorative concept.

### Real operation
1. Start PLAY NOW, use first finger to hold one of the original W78 physical move buttons (W/A/S/D). Its **unchanged** `A7FirstPersonOperator.set_key()` moves the **same original** `CharacterBody3D.move_and_slide()`.
2. Place a second finger on the **free right-side 3D world** (above the original W79 five-phase mission dock, below the top toolbar, outside the W82 live compass and movement buttons); drag horizontally/vertically to pan actual original W70 body/camera.
3. The W83 `A7DualTouchLook.gd` captures the **InputEventScreenTouch.index** of that second finger, accepts only **matching** `InputEventScreenDrag.index`, feeds the physically measured **Godot 4.4 `screen_relative`** (unscaled with stretch) into the existing original `A7FirstPersonOperator.rotate_view()`. The camera is not a 2D screenshot and no actor position is assigned.
4. A new start on W78 movement, W79 original machine action, W82 compass, or W80 top MENU/RU-EN is **never captured** by the world swipe. Another independent look finger cannot hijack the active one.
5. Releasing look preserves walking until the separate movement finger is released. Focus loss/pause calls original `A7TouchFieldControls.release_all()` and cancels gesture; screen resize, MENU exit and desktop return also cancel captured touch ID.
6. Large input deltas clamped to 90 source pixels per actual event (no instant spin), small native portrait-only hint is mouse-ignored, and landscape retains an uncluttered real 3D scene.

All original W63–W82 physical rules, 12 real six-shift core decisions, three real machine puzzles, 3.2m/4.0m proximity security, same true Godot viewport and source save system remain intact.

### Exact-source build / acceptance
- Parent commit pinned to `239af2787e287da7674cf49e533f2dbc99bdc1cb`. Only six changes: original screen wiring, new indexed-gesture node, 1 native test, 1 actual CDP browser runner, docs, workflow.
- No original physics, field interaction, mission, checkpoint, mobile button, or prior test changed.
- **12 Godot 4.4.1 native source tests**, including W83 original two-finger simultaneous walk+look, camera YAW and eye PITCH, UI exclusion, extra finger rejection, release/resize/focus/exit, all previous W63–W82 regressions.
- Re-export real source-compiled Godot 4.4.1 WASM/PCK at exact PR SHA; verify compiled WASM header and build evidence.
- Three real Chromium drivers: existing original W81 real touchscreen 7 frames, W82 real navigation 5 frames, new W83 **CDP Input.dispatchTouchEvent real simultaneous two touch IDs** in 390×844 and 844×390 with original world movement, yaw/pitch, source range rejection, MENU exit. Six additional original frames.
- **18 total original WebGL screenshots** from exact source SHA, byte length/SHA-256 verified, no screenshots fabricated or cherry-picked.
- Required 3/3 CI source-immutability / native + actual browser / release-safe, with software PASS only after all jobs green.

Official Godot 4.4 reference: https://docs.godotengine.org/en/4.4/classes/class_inputeventscreendrag.html (prefers `screen_relative` for aiming across stretch factors). On real hardware the DOM/CDP simulation must be independently confirmed.

### Strict release HOLD
Do not call this physical iPhone/Android certified: actual multi-touch responsiveness, canceled gestures on lock/notification, notches/safe-areas, multitouch latency, consumer-GPU sustained 60fps, 10–15 minute external-human full mission completion, production-grade AAA art/animation/audio, rights clearance, and commercial publishing are all **NOT APPROVED**. Do not merge to `master` until exact-head software CI and review. Software correctness is not commercial world-class completion.
