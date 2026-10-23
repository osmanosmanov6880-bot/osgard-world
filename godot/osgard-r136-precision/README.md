# OSGARD R136 Precision Service Cell — executable Godot source

This is a **standalone, additive Godot 4.4 Web-compatible reconstruction** created for direct GitHub publication. It does **not** claim to be a byte-for-byte copy of the previously reported 544 MB R136 archive; that source archive was not available for upload.

## Implemented
- True 3D procedural industrial cell: modular floor, server/circuit trays, fans, wiring headers, fasteners, gantry and hinged service door.
- Physically separate animated carriage, telescope, jaws, door, and four fans.
- 20-second bounded mechanical demonstration cycle; emergency stop **E**, continue **X**.
- ECO / HERO geometry toggle **H**; camera orbit by right-drag or touch, zoom by wheel or pinch.
- 12 reusable metallic/dielectric/emissive materials and single-pass vignette.
- No credential dependencies, network controls, external assets or real machine telemetry.

## Run
Open project.godot in Godot 4.4.1 or newer and press F6 on scenes/Main.tscn.
Russian HUD and mouse/touch controls. Native headless smoke: `godot --headless --path . --script res://tests/smoke.gd`.
Web export: `godot --headless --path . --export-release Web build/index.html`.

## Safety and limitations
Laboratory simulation. The scene cannot command real infrastructure. GPU performance and browser compatibility must be verified by GitHub Actions and on target hardware. The full prior R136 asset pack, Godot app integration, and any commercial license review remain outside this source-only release.
