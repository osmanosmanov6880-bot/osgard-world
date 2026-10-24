# NEBULA R21 — утверждённый АВРОРА HUD, реальный полёт и телефон

This change implements a *playable* Godot 4.7.2 Compatibility/WebGL
iteration targeting the **user-approved Aurora screenshot**. It does not
replace the game with a static image, visual-only demo or new empty
Unreal project.

## Что исправлено по замечаниям

### 1. «Не могу ехать» — реальная физика движения
- Ship is still a `CharacterBody3D` with an actual `CollisionShape3D`.
- Applies thrust acceleration, exponential drag, velocity inertia, smooth
  angular acceleration/damping, banking, pitch auto-level and limited
  ascending/descending motion. Sliding collisions compute head-on closing
  speed and realistic damage relative to impact; not bulletproof/invisible.
- Normal speed cap 96 m/s, afterburner 152 m/s. Figures are *design
  parameters*, not verified device FPS or real aerospace simulation.
- Initial Aurora flight line relocates obstructing base towers without
  deleting any of the **360** original buildings; saved positions that
  overlap collision solids are relocated to a validated free launch point.
- Camera raycasts into the actual physics space to prevent walls from
  filling the viewport; camera follows with smooth spring-like damping.
- Native regression verifies a collision-free takeoff point and at least
  6 m of forward movement during **37 real physics frames**, not simply a
  source contract or UI animation.

### 2. Пересветы, дешёвый шрифт и тяжёлый HUD
- Reduced sun intensity, ambient fill, emissive windows and the postprocess
  bloom. PBR materials, 512px/384px normal/ORM maps and all 360 towers are
  preserved. Sunset-style steel and glass receive less aggressive contrast.
- Top-left semi-transparent mission card, right objective, bottom-left
  radar, bottom-right real-speed/hull/shield/boost dashboard. Small
  compass with physically computed target bearing replaces generic HUD
  decoration; no non-working controls.
- `SystemFont` preference list: Inter → Manrope → Segoe UI → Noto Sans →
  Roboto → Arial, preserving Cyrillic fallback where installed.
- FOV follows actual velocity, and the camera stays in the playable
  flight corridor. F12 switches Aurora light looks, F3 quality and F10
  screenshots all remain available.
- This renderer is **Godot Compatibility WebGL**, not Nanite, Lumen or
  guaranteed Unreal Engine 5 photorealism. Professional captured assets
  and hardware visual QA are still necessary for genuine AAA graphics.

### 3. Телефон / планшет
- New `mobile_controls_r21.gd` draws lightweight responsive on-screen
  joystick and 8 touch targets: gas, boost, fire, guided missile, rise,
  descend, hangar, and camera.
- Tracks independent finger indices for simultaneous joystick, thrust and
  boost/fire. On release, all controls reset; while the shop is open they
  cannot steer or shoot.
- New compact HUD behavior for narrow/portrait displays and touch devices;
  desktop retains full approved cockpit composition.
- Web shell is rebuilt with `viewport-fit=cover`, responsive viewport
  dimensions, `touch-action:none`, Russian accessibility label and
  mobile-safe fullscreen canvas **every time** GitHub exports Godot.
- Detects touchscreen on-device; doesn't clutter a desktop with touch
  buttons. Native automated smoke forces touch mode to exercise multiple
  simulated fingers on exactly the same gameplay ship.
- Portrait and landscape browser are supported; mobile GPUs still
  require performance measurements. F3 ECO is available for weak hardware.

## Игровые кнопки

| Action | Desktop | Phone |
| --- | --- | --- |
| Fly / accelerate | W / S | ГАЗ and reverse on joystick |
| Turn / pitch | A/D and Up/Down | Left joystick |
| Ascend / descend | E/Q | ВЫШЕ / НИЖЕ |
| Boost | Shift | ФОРСАЖ |
| Shoot | Space | ОГОНЬ |
| Launch purchased missile | R | РАКЕТА |
| Purchase in Aurora | H | АНГАР |
| Chase camera | F2 | КАМЕРА |
| Quality / hardware FPS | F3 / F7 / F9 | F3 via hardware keyboard; ECO starts automatically on weak devices |

## What was NOT changed

- All ten Helios story missions, gameplay save keys, ship packs,
  weapons and rockets, assistants, premium authorization, and real
  Stripe payment gating remain intact.
- Existing R17/R20 full-fidelity baked materials, R18/R19 sector GPU LOD,
  R16 pooled beams and missile physics remain active.

## Release acceptance and caveats

1. All native source checks and material baking (R17+R20) green.
2. Godot editor import and real 3D runtime smoke + flight movement pass.
3. WebAssembly game export and responsive HTML checked.
4. Successful main-branch native export, checksum-verifying isolated SSH,
   and active production Nginx.
5. **Physical GPU only:** screenshots via F10, frame times via F7 and JSON
   via F9; verify controls in Android Chrome and iOS Safari, both
   portrait and landscape.

A passed native Godot test proves scene and gameplay code functioning
there; it does **not** prove that every browser/device can render at 60FPS,
nor that visuals match the approved cinematic concept pixel-for-pixel.
Hosted Chromium SwiftShader screenshot capture was inconclusive in R20.

Production URL after a successful release:
`https://osgard.world/games/remix/arena-v2/nebula-3d/?r21=1`.
