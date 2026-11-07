# NEBULA R62 — exact four-blob native release candidate
**Status: DRAFT CANDIDATE; NOT YET PUBLIC.** Public verified and rollback version is R61.

## Immutable source/export ancestry
- R62 source [PR #772](https://github.com/osmanosmanov6880-bot/osgard-world/pull/772), HEAD `92f53410726987573727cf63d06df23ca0e2e909`, **5/5 checks SUCCESS**.
- Source merge `94cf29363c15247a9dddb9a93dd385c9b52bef43` into `master`.
- Godot 4.7.2 post-merge Web export [#42324906153](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42324906153), sole-child commit `1c6bf1fd240c762490789fd7f546229846037342` whose only parent is `94cf29363c15247a9dddb9a93dd385c9b52bef43`.
- Four original Git SHA-1 asset blobs (no rebuild/alteration in release PR):

| Native Web asset | Original Git blob SHA-1 |
| --- | --- |
| `index.html` | `b84e78ab301c907d6079488459d034be728ad86e` |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` |
| `index.pck` | `93b203c585f0c43d19decfa8a8656611db4495ea` |

## R62 authentic game and visual acceptance evidence
1. **Actual industrial hangar and cameras:** 4 Camera3D presets (overview, cockpit, engines, underside) preserving true 3D motion; enclosed actual MeshInstance3D diagnostic bay with calibration rails, optical scan bar, bounded unshadowed SpotLight3D, quality-tier restrictions.
2. **Independently distinct hull mechanisms:** NX-08 scout, NX-12 interceptor, NX-21 guardian have matching garage and flight geometry, physical wing flaps, gear, cockpit frames, 1/2/4 engine guides; real ammo/CR and saved progress remain untouched.
3. **Godot R62 native acceptance:** `NEBULA_R62_CINEMATIC_REAL_HANGAR_4_VIEWS_ACTUATORS_SUCCESS` reported in PR [#42323912961](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42323912961).
4. **Actual PC Chromium flight:** `NEBULA_R25_BROWSER_FLIGHT_SUCCESS`; real W motion +14.46 meters, mission gap improvement 22.10 m, real heading steering 10.94°. Robust actual-click tests enforce exactly one Godot pressed event and requested ON/OFF state, including delayed SwiftShader acknowledgements; no bypass or fake clicks.
5. **Actual mobile Chromium:** `NEBULA_R31_MOBILE_TOUCH_SUCCESS`, 390×844 CSS, actual `Input.dispatchTouchEvent` and native physical flight.
6. **Actual live WebGL visual:** PR native evidence [artifact 13554462118](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42323912961/artifacts/13554462118) has `r11-1280x720-max.jpg`, 112493 real JPEG bytes, `report.json` `visual_capture_confirmed=true` from `webgl-framebuffer-readpixels`. Initial CDP screencast and `toDataURL` attempts failed but strict live readback succeeded. This is hosted software renderer, **NOT** real-device/real-GPU/FPS/8K/AAA certification.

## Protected release gate
- The original R61 public release [4/4 HTTPS #42320944279](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42320944279) remains the rollback. Before this release, all latest-head identity/lineage/negative-test/readiness/frontend/launcher CI must succeed on the R62 release candidate.
- Then protected SSH publication must report actual success and an independent **public HTTPS 4/4 exact-byte** verifier must confirm all four new files. Never mark live from `master`, SSH startup or Git blob check alone.
- Android/iPhone physical hardware QA **NOT_PERFORMED** and `hardware_qa_certified=false`; local CR currency has no relationship to payment authorization.
