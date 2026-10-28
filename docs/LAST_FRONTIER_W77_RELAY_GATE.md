# LAST FRONTIER — W77 / TRUE PHYSICAL SECTOR GATE

28 Oct 2026 • Godot 4.4.1 • source-bound original A7 playable level, not screenshots.

## Actual new gameplay

The player's physical industrial route has a new *real* industrial two-leaf 3D blast door between reactor sector CORE and relay sector 02, located at world-space `Vector3(6.4,1.86,13.55)`. It is a genuine `StaticBody3D/CollisionShape3D` on collision layer **1**, matching the original W70 first-person `CharacterBody3D`; simply moving the character cannot pass a locked door.

The door is a **source-authoritative traversal gate**, unlike purely decorative warning text:

- Ordinary original W70 exploration and W71 non-extended mission remain freely navigable and never display or collide with this W77 door.
- W72/W76 extended physical operation at genuine phase **0/1** makes the real collider SOLID and closes the actual two leaf meshes. All core incident decisions are still controlled only by the unchanged original `A7CascadeCore`; the W77 door cannot write gameplay results, health or invented actions.
- The original physical **six valve detents + E inspection + PUMP/SCAN** is one real accepted sequence that progresses mission phase to **2**. Only then does the collider turn OFF (deferred to Godot physics) and the two actual PBR mesh leaves slide physically into two frame recesses, with one real animated opening and distinct in-world lock-to-open status lighting.
- The actual first-person physical player can now cross the previously blocked coordinates via genuine `CharacterBody3D.move_and_slide()`, not a teleport or fake test bypass.
- Original PBR profile materials (`reactor_shell`, `dark_steel`, `painted_hazard`) are reused from the verified W68 texture cache. 16 source-authored real 3D meshes, true physics obstacle and diegetic light; on ECO the additional light and close-up detail hide but the collision and gate mechanic stay real.
- Reduced motion preserves the mechanics but skips animated sliding. The immersive RU/EN single-goal text shows whether passage is actually locked/unlocked. 390px layout suppresses redundant 3D text while keeping the door physically there.

## Genuine mobile art QA fix from W76 browser pixels

Inspected the **actual source-bound W76 Chromium 390×844 screenshot**, not a generated mockup. It showed a serious real usability defect: the long Russian desktop title wrapped into a two-character-wide column, expanding the EN/PLAY/PANELS header row to nearly **400 pixels high** and pushing the playable 3D scene below the fold.

W77 corrects the original Godot `HFlowContainer` responsive composition: on widths under 640px the brand becomes a deliberately compact, single-line bilingual title on its own row; the action buttons use true 40px minimum height, rewrap into short rows, and the native 3D stage remains the dominant content. Desktop keeps the original title. The W77 **real Chromium browser acceptance explicitly fails** if the physical 390px brand is tall, the Play/Panels buttons exceed 65px, or the actual 3D world begins too far below the screen top. Native Godot verifies the compact dimensions too. This is a tested implementation change, not a new reference image or cosmetic aspiration.

## Source protection

Base is W76 exact source SHA `11f56e282da96f809e17553fa86e76440d48a5d9`. [W76 true real browser and native accepted CI](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40682788204).

W77 changes **only seven** paths: `A7SectorBulkhead.gd`, integration in `A7CinematicStage.gd` and `A7CascadeScreen.gd`, new native physics test, new source-authentic browser screenshot acceptance, this document, and CI workflow. All original game action code, mission phase rules, W70 physical actor, W72 independent valve/relay/sync math, W73 real-camera raycast and SHA-backed session checkpoint, W74 analog controller and source-based materials, W76 original 15-waypoint system and all original tests remain byte-for-byte unchanged.

## Tests and release policy

Native Godot tests actively hold `W` while original CharacterBody3D moves into the locked door, observe the real physical stop at z<13.25, then solve *unchanged* original core+equipment actions, observe the collider disabled and walk past z>15.0; test source event count, two leaf movement, genuine status and EQ/reduced-motion, RU/EN and 390px.

Chromium exports the **real Godot WebAssembly** and captures six actual unedited source-SHA-backed screenshots after keyboard Play Now, first-person walk, Tab restore, 390px and locale toggle, plus original W76 browser gameplay regression for twelve total frames. Chromium cannot replace the native full physical gate crossing test; that happens in actual Godot physics engine.

**NOT AAA certification**: procedural PBR shapes still need professional environment/character production, independent art direction, human testing, hardware performance, original licensed content and commercial title clearance. Remain in unmerged DRAFT until exact-head 3/3 CI PASS. No production publication or master merge.
