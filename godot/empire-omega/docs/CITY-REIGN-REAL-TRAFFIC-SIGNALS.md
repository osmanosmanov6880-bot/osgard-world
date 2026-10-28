# CITY REIGN — metropolitan cinematic street signals, A17–A19

**Status:** source-authored Godot 4.4.1 city-road visible art candidate, subject to native + Chromium QA. No licensed photoreal hero signal models, no production deployment.

## Before
Real original 16 intersections (x,z in -156,-52,52,156) have one thin pole with simple unshaded red and green BLOCKS facing road -Z, while real `TrafficSignalGrid.permitted()` allows X movement in phase 0 and Z in phase 1. The old -Z-facing visual showed green in phase 0; that contradicted what ambient traffic drivers actually did.

## Now
- **16 source-authored roadside signal supports**: physical steel pole and welded X/Z cantilever, off the unmodified 10-metre road.
- **32 distinct source-authored 3D housings**: one box facing arriving X drivers, one facing arriving Z drivers at every genuine intersection. Each is a genuinely closed die-cast housing with 3 beveled metallic rings and 3 protruding sculpted sun hoods, not a 2D signal icon.
- **96 genuine convex radial 3D emissive glass lenses**: 16 intersections × 2 orientations × 3 LED colours, grouped into six source-bounded render batches.
- Exactly **9 original Godot MultiMeshInstance3D draw nodes** for all signals: 1 metal pole batch, 2 direction-specific housing batches, 6 shared RGB lens batches. Each reuses the same source mesh and PBR finish, no material or node creation on each phase change.
- Existing original LOW mode 16 physical poles and simple lamps remain in the scene, **not deleted**. LOW hides the new GPU nodes and restores the legacy source art; STANDARD and CINEMATIC show the actual detailed new 3D sculpture, hide old duplicated geometry.
- True original cycle **24 seconds**, each right-of-way phase remains **12 seconds**. Near phase end, a 1.5-second yellow safety warning replaces green on the currently permitted lane. Yellow **does not change** driver AI permissions or fine logic.
- Exact source truth: `permitted(waypoint,direction)` remains unchanged. At phase 0 X shows green and Z red; phase 1 X shows red and Z green. A frame at amber warns of imminent phase change without advancing the actual law.
- The 12 original traffic cars, 34 pedestrians, city data/save, traffic offences, financial rules, collision masks, pedestrian yielding and mission identity are unchanged.
- No content from real traffic-signal manufacturers or copyrighted 3D meshes is imported.

## Acceptance
- `v119_city_reign_aaa_street_signals.gd` instantiates original shared source, inspects real GPU surfaces, housing triangle budget, every physical 3D intersection transform, exact 16/32/96 geometry, all 4 red/amber/green visual states, original law across cycle boundaries, and actual full game with source-only GPU LOD.
- SHA-locked real Godot R42 import + original v14 collision test, v113 city, v114 traffic family, v119 new signal QA, public-release protection test and signed source digest.
- Full original Chromium 3D city regression must pass on exact source HEAD.
- Independent physical-screen review, signal readability for night/weather, color-blind alternative cues, phone thermal/FPS, controller driving and licensed professional art still required for AAA acceptance.

**Protected:** R90 staging only. No `master`/R87/public/SSH or storefront release.

## Source-only real 3D browser optics gate
`tests/city_reign_real_signal_pixel_fixture.gd` and `.tscn` are labelled TEST-ONLY, never the production game scene. CI temporarily selects this scene only in a disposable private checkout while exporting authentic Godot 4.4.1 WebGL. It inspects the real 16-junction `TrafficSignalGrid`, not a separate visualization code path. Chromium checks the actual visible RGB pixels of original full 3D red/green directional phase, 1.5s yellow warning and original low-quality fallback.

Pixel assertions cover real rendered scene variety plus nontrivial source-native phase/warning/LOD changes; raw PNG/JSON and exact source SHA are saved to GitHub Actions. Physical GPU and accessibility signoff remain separate unproven gates. No source-engine screenshots are invented or sourced from the internet.
