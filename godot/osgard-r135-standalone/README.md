# OSGARD R135 — recovered Godot 4.4.1 standalone service spine

This is a real standalone Godot project reconstructed from the user's R135 upgrade. It uses the **original** R135 models and PBR maps, but does not claim to recover the missing 193-file R134 baseline. The existing R136 Precision Cell in `godot/osgard-r136-precision/` is preserved without modifications.

## Published downloads
- [Source Godot project, HERO/ECO GLBs and all PBR textures](https://github.com/osmanosmanov6880-bot/osgard-world/releases/download/r135-standalone-20261024/OSGARD_R135_GODOT441_SOURCE_PBR_GLB.zip)
- [Native Godot HTML5 Web export](https://github.com/osmanosmanov6880-bot/osgard-world/releases/download/r135-standalone-20261024/OSGARD_R135_GODOT441_WEB_PLAYABLE.zip)
- [Release manifest with SHA-256 hashes](https://github.com/osmanosmanov6880-bot/osgard-world/releases/download/r135-standalone-20261024/R135_RELEASE_MANIFEST.json)

These are **real downloadable binaries** on GitHub Releases. The Web export contains a 118,659,392-byte PCK, so it is NOT yet hosted as an active OSGARD site route. Do not advertise `/games/r135-service` as playable online until an external asset host and browser GPU smoke are verified.

## Engine and original source
- Godot **4.4.1**, Compatibility renderer, standalone `project.godot` / `Main.tscn`.
- ECO **21,116 triangles** and HERO **60,288 triangles**, original deterministic GLBs, 12 PBR materials with 36 original 1024×1024 texture maps.
- `tools/build_r135_service_spine.py` reproduces the original model/material bytes with `requirements-r135.txt`.
- `R135ServiceDirector.gd` retains R135 mechanics with two original invalid tuple-style loops corrected for GDScript 4.4.

## Play
Open this directory as a project in Godot 4.4.1 and run `Main.tscn`. It starts in ECO mode to limit memory usage. Mouse or touch drag: orbit camera; wheel: zoom; **Q**: ECO/HERO; **F**: service hatch; **Space**: pause/resume; **R**: camera reset. On-screen buttons provide the principal controls.

## Verification and limitations
- [Exact-asset reproducibility, native tests, and Web export: passed](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40069720298).
- [Clean-source release packaging and repeated native smoke: passed](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40070005903).
- The repository has a separate native master-branch smoke workflow in `.github/workflows/r135-master-native-smoke.yml`.
- Godot *headless* smoke and Web export confirm the engine/import/build pipeline, **not** production GPU performance or real phone/browser rendering. No real-world device control, telemetry, or independently attested hardware benchmark.
