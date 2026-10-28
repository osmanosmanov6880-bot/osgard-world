# CITY REIGN — AAA HERO GARAGE ART CONTRACT

**This is real original playable Godot 3D**, not a concept render, yet it is **not a commercially approved AAA car collection**.

## Four player-owned visual silhouettes
- **Compact** — original source reference coupe remains entirely untouched (original FlowBody and AerodynamicGreenhouse mesh identity preserved). Original windows, wheel animation and glossy finish survive.
- **Courier** — full-length, higher, wider rooftop profile and more purposeful box-sided metalwork. The *same* two original source mesh nodes now use new authored profile geometry; no second model instance or physics body.
- **Executive** — slightly lengthened roof extremities, sleeker lower roof profile and brighter existing paint finish. The performance numbers and upgrade/purchase costs still come from the original `vehicle_catalog.gd`.
- **Utility** — wider and taller, squarer greenhouse with raised hood profile. Real vehicle silhouette changes; existing 5.4 × 2.7 × 1.5 metre collider and all four wheel/suspension rigs are NOT changed.

Authored via `city_reign_player_vehicle_profiles.gd`, reusing exact `horizon_coupe_sculpt.gd` closed profile generation and six globally cached new ArrayMesh source assets (three new bodies plus three new roofs).

The current car still has its original four full volumetric glass nodes, brake lights, headlamps, original 4 independent suspension wheels, unique body parts and legacy blacked-out cubes. The existing sloped glass geometry is repositioned in place for the selected greenhouse, and its native rest transform is updated so the real spring/suspension simulation does not undo the car model on the next frame.

### Strict original gaming constraints
- No new per-car MeshInstance3D, model import, additional shadows or colliders.
- No new save fields, wallet changes, campaign mission IDs or acceleration curve modifications.
- Fully reversible selection via existing real `VehicleController.apply_variant`.
- Visual identity never fabricates ownership: the original game decides whether a car is purchased. Source art is a representation only.
- The three new body/cabin pairs are held in a bounded material cache and reused.
- Authentic original Godot native `v115` regression; original R4 car, physics, real full scene and 3-tier graphical pipeline tested separately.
- Full SHA-specific Godot native/Chromium WebGL still required before R90 staging merge; no public release.

### Remaining world-class gates
Professional original/licensed high-poly hero cars with homologous profiles, authored tires, UV/PBR detailing, animation rig, vehicle camera shots, real-driver handling tests, 3 real mobile phones plus desktop 60 FPS P95 proof, legal sound/IP verification, accessibility, independent art director reference signoff, release gate. **HOLD**.
