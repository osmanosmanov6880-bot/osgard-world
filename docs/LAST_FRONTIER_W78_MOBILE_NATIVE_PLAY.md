# LAST FRONTIER W78 — TRUE IN-WORLD MOBILE CONTROLS

**Baseline:** verified original W77 commit `c177b554be9b10846c53d4996855b0a2d6f57103`, [original 3/3 CI PASS](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40689573402). Godot 4.4.1. October 28, 2026.

## Product result: an actual playable mobile UI, not a screenshot

W76 gave desktop PLAY NOW and cinematic viewport; W77 added real phase-gated collision and fixed the mobile header. However, on narrow devices the actual touch movement/inspection controls were a long row **below** the live 3D viewport; users had to scroll while playing. W78 moves the essential controls onto the original actual 3D screen as a compact transparent single-row field panel, while preserving the complete desktop layout and original physics.

The new **`A7TouchFieldControls.gd`** is a real native Godot `Control` with eight source-connected `Button` inputs. The user can hold A/W/S/D to **actually walk with W70 CharacterBody3D.move_and_slide**, hold arrow look controls to **actually rotate Camera3D** continuously with frame-independent angular speed, tap G to call **the original W73 real physics-ray equipment interaction**, and tap E to call **the original W71/W72 distance/solution-gated physical inspection**. This preserves all ordinary original six-cycle core gameplay and avoids screen-space fiction.

The interface only exists visually when:
- root viewport narrower than 640px **and**
- player explicitly entered original immersive 3D mode **and**
- original native CharacterBody3D piloting is active.

In all other modes the actual in-viewport controls disappear; button release and leaving immersive mode also release **all original held movement keys** and held camera look, preventing stuck movement. Controls use actual root viewport width (32px minimum at 320px, 39px at 390px, 48px height), translucent obsidian styling, readable 18px labels, subdued bronze/cyan accents, focused G/E affordances and localized RU/EN tooltips. The original `stage_shell` HUD and fully original Godot SubViewport remain the actual engine canvas. Desktop is keyboard/gamepad first, with no extra mobile buttons.

## Strict original-game source protection

W78 only adds `A7TouchFieldControls.gd`, wires it to existing genuine input callbacks in `A7CascadeScreen.gd`, adds native/browser QA and these docs/CI. No modifications to W63 A7 calculations, W70 physical actor, W71–W72 field game authority, W73 real RayCast3D/checkpoint, W74 controller, W76 objectives or W77 collider. The original W77 cinematic focus cancellation is also called from actual manual touch movement and look.

## Native and real WebGL acceptance

Godot unit test `test_w78_touch_gameplay.gd` instantiates the original game: tests physical 36-frame movement by real Button.down/keyup, true native Camera3D look, original W73 ray for G with source acceptance and replay journal, actual valve solution + E inspection, true 320px controls, hide/show, forced release of held keys, RU/EN tooltip, desktop auto-hide, plus original game rule isolation.

Chromium runs the **original 4.4.1 Godot compiled WASM** under browser software graphics and sends real pointer mouse-down/up on source-reported in-game buttons, proving physical CharacterBody displacement, correct refusal for real G when too far from equipment, reversible Tab, original RU/EN and both 390px/320px views with six actual unmodified PNG frames. W77 old browser test is re-run to prevent breaking the physical bulkhead or its responsive design.

All source proof and original images must match the final exact Git SHA, and three CI jobs must pass. The green software gate does NOT certify physical Android/iOS touch hardware, 60fps on real phones, independent human experience, professional AAA art, commercial name rights or publication. The game remains a draft in an experimental branch pending independent W75 evidence collection and explicit product GO.
