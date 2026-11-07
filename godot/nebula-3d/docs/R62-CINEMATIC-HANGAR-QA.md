# NEBULA R62 — real cinematic 3D inspection hangar

**DRAFT SOURCE, NOT THE PUBLIC RELEASE.** The currently verified public software version is R61 with 4/4 exact HTTPS parity [#42320944279](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42320944279).

## Four implemented gameplay-facing blocks

1. **Four actual camera presets.** Overview, cockpit, exhaust and underside. Camera3D orbits the real 3D ship in its isolated SubViewport/World3D. Smooth eased camera movement and real mouse/touch orbit/zoom survive; invalid views are rejected.
2. **Physical airframe mechanisms.** R62 creates actual MeshInstance3D control surface hinges, landing struts and cockpit window framing for all three owned NX hulls. Engine guide count is 1/2/4 by genuine R55 model. Hinges and landing struts articulate under inspection, never affect the live player's physics or CR wallet.
3. **Actual industrial bay diagnostics.** A real gantry adds structural pillars, service guide rails, optical scanning beam and one controlled unshadowed SpotLight3D. Selection changes lights and scanning volume; mobile quality disables the worklight and small details, retains real 3D geometry and flight safety.
4. **Real-model precision detailing.** `fleet_airframes_r55.gd` adds distinct NX-08 reconnaissance pods, NX-12 twin-engine heat baffles and NX-21 armored panels. The same extra geometry appears in the live game and isolated inspection preview, not a fake photo.
5. **Russian adaptive interaction + native tests.** Four selectable touch buttons are placed above the 3D viewport in portrait and landscape, do not intercept the primary launch button, and preserve existing store/crew/mission sections. Native Godot runtime smoke asserts all four views, real geometry counts, distinct drive counts, mobile performance tier, no premature flight unlock and unchanged credits.

## Verification and scope

- Run Godot 4.7.2 editor parser, native smoke and real WebAssembly Chromium PC and 390×844 touch tests. Require `NEBULA_R62_CINEMATIC_REAL_HANGAR_4_VIEWS_ACTUATORS_SUCCESS`.
- No generated screenshots are substituted for evidence. R11 hosted SwiftShader visual capture currently FAILS and is NOT real GPU/AAA graphics certification. A separate R11 improvements pass must preserve fail-closed visual detection.
- Physical Android/iPhone hardware QA **NOT_PERFORMED**; nothing claims 8K native output or hardware FPS.
- Do not merge before 5/5 source CI. After merge require actual post-merge Web export, signed four-Git-blob release approval, rollback-safe SSH deployment and independent 4/4 public HTTPS parity. R61 remains the rollback until then.
