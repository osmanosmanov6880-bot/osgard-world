# OSGARD R135 asset integration audit — 2026-10-24

Target repository: `osmanosmanov6880-bot/osgard-world`. Existing R136 Godot application: `godot/osgard-r136-precision/`. DO NOT overwrite this project with R135 root files.

## Verified input
- Uploaded R134→R135 archive: 74 entries, 72 payload files, 108 MiB uncompressed (approx).
- Uploaded R135 assets archive: 41 entries, all 41 files are byte-for-byte identical to matching files in the delta payload. Do not duplicate them.
- 2 GLB service spine variants (~34 MiB HERO and ~33 MiB ECO), 36 PBR images (12 materials x albedo/normal/ORM).
- Controllers: R135ServiceDirector.gd and R135HardwareSweep.gd; cinematic shader and Python build/test utilities.
- R135 delta is based on EXACT 193-file R134 full project. It cannot be safely applied directly to the R136 standalone scene or the OSGARD website.
- Upstream provenance: real GPU test=false; Godot executable test=false; production approved=false.

## Integration policy
1. Restore exact R134 full baseline, validate all SHA-256 values against OVERLAY_MANIFEST.json.
2. Run `python apply_r135_delta.py --baseline <R134_DIR> --overlay <R135_DELTA.zip> --out <R135_OUT>`.
3. Keep that recovered Godot project isolated under `godot/osgard-r135-service-spine/`; preserve R136 unchanged.
4. Confirm Godot 4.3+ project import, resource links, shader compilation, scene load, controller interactions.
5. Run source tests and a *real* GPU benchmark; preserve actual results, do not infer FPS from offline Python tests.
6. Decide whether a later R136 integration is appropriate based on scene architecture and measured budgets; only then integrate resource-level components (not Main.gd / project.godot replacements).
7. Publish web exports only after CI and user-visible QA. Use Git LFS or a release asset if repository policies require it; do not commit duplicates.

## Status
Audit complete. Archive-to-R136 merge and live deployment NOT performed. The exact R134 base and working Godot runtime are not available in these two uploaded archives. Production approval remains blocked.

This report documents the safe integration boundary to avoid a misleading or destructive R135→R136 merge.
