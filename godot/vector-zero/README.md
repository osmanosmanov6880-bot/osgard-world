# VECTOR//ZERO — BLACKFIELD PROTOCOL (Godot 4.7.2)

**Artifact:** Independent, playable Godot 3D vertical slice. This is **not** a claim of photorealistic AAA production completion, and it does **not** replace the existing `/games/vector-zero/` browser game.

## What is implemented

- Constructed multi-story laboratory in native Godot 3D using original procedural geometry: deck and metal panelling, structural columns, suspended luminaires, cryopumps, cable conduits, 3D wall graphics, emitter cradle and receiver structure.
- Animated plasma-core geometry, triple rings and magnetic field coil; PBR metal/roughness, multiple physical lights, color contrast, fog and restrained bloom/glow.
- Deterministic magnetic acceleration with attract/repel polarity + ballistic gravity, drag and fixed time-step integration.
- A **real calculated 3D trajectory preview**, sharing the *same simulation method* as the projectile.
- Three progression stages; all have solutions over accessible angle and polarity inputs. Accurate collision/win area is indicated in world geometry.
- User interface is Russian-first, with a single top objective and a three-control HUD. Controls remain visible even when playing.
- Camera-switch view, aiming control, fail/restart, completed stage, next stage.
- Native headless regression tests (scene, UI, physics consistency, solvability, progression).
- GitHub Actions: Godot 4.7.2 import + native tests + real Godot Web export; **build is only a CI artifact**, not auto-deployed.

## Run

1. Install Godot **4.7.2** from https://godotengine.org/download/.
2. Open `godot/vector-zero/project.godot`.
3. Press **F6** on `scenes/main.tscn` or **F5** to start the project.
4. For CLI tests: `godot --headless --editor --path godot/vector-zero --import --quit && godot --headless --path godot/vector-zero --script res://tests/runtime_smoke.gd`.
5. Web build: install the 4.7.2 export templates, then `godot --headless --path godot/vector-zero --export-release Web /absolute/output/folder/index.html`. Host the folder over HTTP(S); do not open `index.html` as a `file://` URL.

### Gameplay

| Control | Action |
| --- | --- |
| Space or primary UI button | Launch; next stage after victory |
| Q | Toggle magnet attraction and repulsion |
| Left / Right arrows or A / D | Change launch angle before firing |
| R | Restart stage |
| Tab | Switch camera |

The glowing cyan path is **computed**, not decoration. If its prediction misses, adjust the angle or magnetic polarity. During flight Q still influences the projectile.

## Rendering strategy and limits

This slice defaults to **Godot Compatibility** to support a Web export of the playable level. Godot 4 Web uses the Compatibility path, not Forward+ (which supports additional GPU features). Desktop forward+ PBR, external licensed high-fidelity environments, cinematic animation, optimized particles, tested PC GPU performance and photorealism need additional asset/art and validation work. No third-party game art is used.

The original production website game and the whole `godot/empire-omega/` project remain unchanged. This is the first independent playable level and a baseline to validate the new visual language before replacing public game routes. Do not treat an uploaded artifact as evidence of a production deployment.