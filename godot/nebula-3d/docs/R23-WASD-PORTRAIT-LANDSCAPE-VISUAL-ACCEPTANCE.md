# NEBULA R23 — FIX THE 000 km/h SCREENSHOT / RU KEYBOARD / PHONE PLAY

**Owner's exact report:** NEBULA R22 still displays **000 км/ч**, the ship
appears parked and the world is dull flat-orange with fake giant blue cone
exhausts. The user wants the *actual game* fixed, not rendered example art.

R23 changes **the existing shipped Godot 4.7.2/WebGL scene, controls and
generated production HTML**. Preserves original 10 missions, purchased ships,
missiles, wingmen, credit saves and R15 server-gated checkout. NO live
Stripe work.

## 1. Physical keyboard moves the ship despite RU / US layout differences

R21 accidentally used `Input.is_key_pressed(KEY_W)`, querying the
*character*. The W keyboard position produces Cyrillic **Ц** while the user
types in Russian, so the game might read zero thrust even if WebGL is alive.

R23 uses **two independent real-user input paths**:
1. `Input.is_physical_key_pressed(KEY_W/A/S/D/Q/E)` in the genuine
   `CharacterBody3D` physics loop; retains logical-key fallback.
2. Production-generated Godot Web HTML captures
   `KeyboardEvent.code` (`KeyW`, `KeyA`, etc.) at
   **window.capture** and updates one bitfield. Godot reads it once each
   physics tick via `JavaScriptBridge.eval`. This also works when focus
   is wrongly on the page rather than the canvas. Focus is restored
   following a movement key. Browser scrolling is prevented for flight keys,
   key-held bits are reset on blur/tab hide. This is not a fake key event.

There is also a **real engine-powered "▶ НАЧАТЬ ПОЛЁТ" button** on desktop,
connected to ship's physical throttle. It toggles into
"■ ЗАВЕРШИТЬ ПОЛЁТ", and pressing S to reverse disengages cruise.
This gives the owner a direct mouse fallback when keyboard focus fails.

## 2. Phone controls: actionable portrait and landscape

- Existing multi-finger joystick, gas, firing, rockets, boost, vertical
  flight and hangar retained.
- New **ПОЛЁТ** touch target engages/disengages actual engine cruise
  without holding a finger down forever.
- Shallow widescreen phones use a **four-column multi-row layout**;
  in R22 the HANGAR/CAMERA buttons at fixed 188px overlapped
  FIRE/ROCKET/UP in landscape. Portrait keeps more spacious rows.
- End-of-touch handlers release the consumed input properly.
- All existing responsiveness/fullscreen WebGL CSS remains active.

## 3. Clean up the actual pixels

- Removed the all-orange haze by balancing **cool deep-blue upper sky**,
  copper/pink sunset horizon, cool atmospheric distance, a neutral
  blue fill and natural warm sun. More legible contrast, less bloom
  and lower flat warm-fog saturation.
- Reused R20's **original actual albedo+emission PNGs** on all
  **18 Aurora hero tower walls**, replacing flat solid color.
  These are real `StandardMaterial3D` PBR surfaces; no fake photo or
  prerendered image substitute.
- The previous "engine exhaust" kept six enormous solid-looking
  cones visible even at 000 km/h. Their correct actual behavior is
  no visible flame at idle, a smaller translucent ion core and
  faint moving halo at positive throttle, weaker realistic engine
  fill and darker machined nozzles.
- R17/R20 26 pre-baked original maps, R18-R22 physical city and ship
  geometry, distance LOD, F3/F11 dynamic quality remain.

## 4. Native acceptance vs device evidence

Native Godot scene smoke now **actually presses and releases a physical
W key**, measures real resulting displacement and resets it; also clicks
the actual launch button and measures real distance with cruise,
activates the phone cruise touch target, checks 9 unique controls at
844x390 (landscape) and 390x844 (portrait), and verifies the 18
tower PBR textures are loaded. Checks true idle plume suppression.

Source-contract verifies JS physically keyed listener, corrected sky,
real start button and mobile placement.

To release, **all** source checks, R17/R20 prebakes, Godot editor,
native runtime smoke, wasm export, main-branch repeat and isolated
SSH checksum/Nginx deployment must succeed. We will not claim the
preview now equals the user's AAA render, or that any FPS or iOS
device result is proven without physical capture.

### Player quick check

1. Open `https://osgard.world/games/remix/arena-v2/nebula-3d/?r23=1`
   and refresh with Ctrl+Shift+R.
2. **Without changing Russian keyboard layout**, press physical W; speed
   must rise from 000. Press S to brake. If keyboard still fails, click
   **▶ НАЧАТЬ ПОЛЁТ** on the screen to get real acceleration.
3. On phone use **ПОЛЁТ** as one-tap cruise or simultaneously touch
   joystick and **ГАЗ**; landscape must show all non-overlapping controls.
4. Take a screenshot with F10 and a 20-second FPS test F7 / JSON F9
   for physical device comparison.

The client's real screenshot is the source of the R23 design correction.
No user-approved reference image was generated in this work.
