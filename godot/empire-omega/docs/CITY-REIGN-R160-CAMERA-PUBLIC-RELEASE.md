# CITY REIGN R160 — actual cinematic street-level camera in original Godot

**Long-term visual target:** The Matrix Awakens × GTA VI × Forza Horizon 5.
This defines design ambitions, not achieved AAA quality or asset licensing.

### Production blocks: B69–B72

**B69 · Original camera composition:** STREET (default) moves the true
third-person camera 20% closer to citizens and 16% closer to cars on desktop,
and lowers street pitch by 0.065 radians. CLASSIC preserves the original
camera. PANORAMA reveals more real skyline at approximately 1.22–1.26×
distance. On phones the ratios are more conservative, without pitch cuts.

**B70 · Real inputs + persistence:** same InputMap camera_cycle via V,
controller DPAD_RIGHT, and touch Quick Actions. RU/EN/ZH source labels.
Mode persisted as optional user settings; old game saves compatible.
No gameplay state, currency or mission keys changed.

**B71 · Evidence:** Native Godot v133 checks 3 modes × car/walk ×
phone/desktop, real wall-collider raycast, no economics mutation,
reduced-motion preference. Chromium test records actual WebGL screenshots
after V input and checks true 3D pixel differences. No synthetic images.

**B72 · Isolated SSH deployment:** Existing source-locked pipeline builds
res://scenes/main.tscn with Godot 4.4.1, tests the original 40-stage
campaign and gameplay before deployment, publishes only
https://osgard.world/games/city-reign/ via pinned source+SHA256
verification and rollback. The older Omega R87 remains unchanged.

### Honesty and release blockers

Playable technical preview only; independent complete player playtest,
licensed hero assets, real Android/iOS performance, vehicle/character
photorealism and commercial AAA signoff remain open.
