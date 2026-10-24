# OSGARD R135 — recovered standalone Godot 4.4.1 service spine

This additive reconstruction uses the original R135 3D assets/controller without requiring the missing R134 baseline. It does not overwrite the R136 Precision Cell.

**Models:** ECO (21,116 triangles), HERO (60,288 triangles), twelve PBR material families, 36 authored 1024×1024 PNG maps. Original R135 meshes and all material maps regenerate *byte-exactly* from the bundled `tools/build_r135_service_spine.py`.

**Scene:** independent Godot orbit camera, mouse/touch rotation and wheel zoom. Hotkeys: Q quality, F hatch, Space pause, R reset. Default ECO and Compatibility renderer. All motion is **simulated**, with no live hardware command or telemetry.

**Run:** Godot 4.4.1 -> open `project.godot` -> run `Main.tscn`. Native CI checks `res://tests/smoke.gd`; `pytest tests/test_asset_integrity.py` checks embedded glTF PBR resources, full texture set, and source SHA-256.

**Distribution:** self-contained recovery ZIP is provided separately in the user conversation. GitHub Actions assembles its identical original GLBs and textures in the `integration/r135-assets-audit-20261024` branch and exports `public/games/r135-service` only if native QA passes.

**Status limits:** R134 complete project was not supplied, so this is not the exact legacy R134/R135 world scene. Headless CI is not a real GPU benchmark; test final browser performance before wide release.
