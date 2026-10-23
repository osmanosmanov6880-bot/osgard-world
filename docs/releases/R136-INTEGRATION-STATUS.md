# R136 Godot release intake

Status: BLOCKED — original R136 source archive not available in this repository or current working session.

Target repository: osmanosmanov6880-bot/osgard-world
Target integration branch: master

## Reported R136 deliverables (unverified)
- Godot project, 322 files, approximately 544 MB
- 19-mesh GLB asset with ECO/HERO variants
- 9 independently movable nodes, 10 PBR materials
- 97 new tests; 233 selected tests reported passing
- Native Godot/GPU validation and production deployment not performed

## Acceptance requirements
1. Obtain the actual R136 source/archive and verify SHA-256 manifest.
2. Inspect project.godot, license, assets, git-lfs size and existing project boundaries.
3. Import into an isolated subdirectory without overwriting existing games.
4. Run native Godot 4.3+ import, headless smoke tests and web export in CI.
5. Confirm deploy workflow and target URL before merging to master.

This note is not a release, does not contain the R136 files, and does not trigger deployment.
