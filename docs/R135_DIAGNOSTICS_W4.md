# OSGARD R135 W4 — Fault Diagnostics

## Delivered on the integration branch

W4 preserves the original HERO/ECO GLBs, Godot 4.4.1 Compatibility renderer, and the existing four-step training mission. It adds an **optional simulated challenge** with three faults and a proper diagnostic sequence.

### Three simulated fault types

| Attempt | Fault | Correct inspection camera |
|---|---|---|
| 1 | Optical alignment | 2 — OPTICAL HEAD |
| 2 | Cooling airflow | 3 — SIDE INSPECTION |
| 3 | Service interlock | 1 — SERVICE DECK |

Scenarios rotate in this deterministic order, then repeat.

### Five stages and mechanical safety

1. Stop simulated drive.
2. Open service hatch. The optical inspection cannot proceed before the animated hatch is at least 95% open.
3. Select the correct inspection camera and press SCAN TARGET. Wrong camera or premature scan is rejected with a penalty.
4. Close service hatch.
5. Restart simulated drive. The interlock refuses to restart until the lid reaches a fully closed position (5% tolerance).

Attempts to open the hatch while the simulated drive is moving are blocked. All fault sources, lights, states, penalties and scores are synthetic: this is a **game**, not a fault-detection tool for machinery.

### Input

| Control | Keyboard | Description |
|---|---|---|
| START MISSION | M | Existing guided 4-step training |
| DIAGNOSTICS | C | Start 5-stage challenge, rotate simulated fault |
| NEXT VIEW | V | Orbit preset: overview, deck, optical, side |
| SCAN TARGET | E | Camera-dependent inspection |
| ECO / HERO | Q | Original GLB quality switch |
| PLAY / PAUSE | Space | Start/stop simulated drive (interlocked) |
| OPEN HATCH | F | Toggle hatch (interlocked) |
| RESET VIEW | R | Restore camera |

Desktop layout: four columns, two rows. Portrait layout: two columns, four rows. Mouse drag / finger drag rotates camera; mouse wheel / pinch zoom changes distance.

### Scoring and persistence

At successful completion: `max(0, 150 - ceil(elapsed_seconds * 3) - 12 * mistake_count)`. Best score is saved locally with Godot `ConfigFile` at `user://r135_challenge_record.cfg`, not transmitted to any server. Guest browsers in private mode may not preserve it across visits.

### Acceptance required before deployment

- Godot import and smoke: original meshes and textures; legacy training still playable; fault rotates; penalty for unsafe hatch; wait for actual hatch motion; correct camera scan; refusal to resume until sealed; score and eight buttons.
- Browser smoke on desktop keyboard and emulated mobile **touchscreen** must complete training and fault diagnosis. HERO/ECO GLBs must load in WebGL2.
- Signed W4 asset manifest, `.wasm.gz` validation, staging into server release, production HTTP 200/206, MIME, and checksums.
- Older W3 GitHub Release remains available for rollback until W4 production smoke passes.

**Caveat:** software Chromium WebGL2 is not an actual phone GPU or FPS measurement; photorealistic AAA quality is not asserted.
