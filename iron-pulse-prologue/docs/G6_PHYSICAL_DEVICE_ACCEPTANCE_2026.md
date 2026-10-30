# IRON PULSE WORLD G6 — PHYSICAL DEVICE EVIDENCE GATE

Baseline: exact G5 source `736f75b5e7668e44d432d3e9b466c4b20e8b6bb6`; [G5 full CI PASS](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40960859703). This G6 branch is stacked upon G5. The existing game client is unchanged.

## Implemented

`ci/device_acceptance_g6.py` validates **offline, manually submitted** G4 laboratory reports from the existing Godot game against the actual G5 Windows/WebGL ZIP through `release_vault_g5.verify_archive`. The release ZIP and original Git source must match externally trusted SHA-256 / 40-hex source SHA respectively. There is no remote telemetry, private user identifiers, deployment or automatic publication.

### Evidence matrix
- Five required classes: integrated Windows PC in ECO; discrete Windows PC in HERO; physical Android/Chrome midrange and entry-level in ECO; iPhone/Safari in ECO.
- Each class: two independent runs of each GRID, HEAT and AIR act (6 clean 90–600s G4 reports per class).
- Each class: at least 30 minutes active, crash-free soak, collected via 4–16 separately exported G4 sessions. Each segment is capped at 10 minutes by G4, with no truncation or background interruption.
- Each report must be source-generated schema `IRON_PULSE_DEVICE_LAB_G4`, complete, comparable, fixed viewport/profile, valid frame counts/durations/P50/P95/P99/average/estimated FPS and separately hashed with SHA-256.
- Provisional main-loop p95 targets: 16.7 ms for discrete Windows HERO, 33.3 ms for all ECO classes. These are **targets, not observed FPS, not GPU timings, and not a guarantee**.
- Ten explicit manual checks per class: physical device claimed, launch, controls, audio, checkpoint recovery, three acts navigated, crash-free soak, touch/gamepad, thermal notes and request for independent review.
- Rejects duplicate sessions, JSON duplicate keys/NaN, unsafe paths, symlinks, unknown privacy-sensitive fields, fake hardware/production approval, mismatched archive/source, invalid counters and missing classes.

### Generate blank packet on private operator machine

```bash
cd iron-pulse-prologue
python3 ci/device_acceptance_g6.py --init \
  --archive /trusted/IRON_PULSE_WORLD_G5_RELEASE_HOLD.zip \
  --source-sha <TRUSTED_FULL_40_HEX_SHA> \
  --bundle-sha256 <TRUSTED_64_HEX_ARTIFACT_SHA256> \
  --evidence-dir /private/g6-physical
```

It creates an **unapproved** `evidence.json` (all manual flags initially false), with six empty act references per class and an empty soak list. It refuses to overwrite an existing packet. On actual Windows/Android/iPhone, capture G4 diagnostics by F9/F8 or the in-game LAB button, export the G4 JSON explicitly, place it under private `reports/*.json`, and record the hash and relative filename in the corresponding entry. Physical device identification, temperature and controller observations require a consenting human; no such data is automatically collected by this script. Keep raw reports **out of public GitHub**.

### Evaluate candidate

```bash
python3 ci/device_acceptance_g6.py \
  --archive /trusted/IRON_PULSE_WORLD_G5_RELEASE_HOLD.zip \
  --source-sha <TRUSTED_FULL_40_HEX_SHA> \
  --bundle-sha256 <TRUSTED_64_HEX_ARTIFACT_SHA256> \
  --evidence-dir /private/g6-physical \
  --output /private/g6-summary.json
```

- Exit 0: `READY_FOR_INDEPENDENT_REVIEW` — **not** hardware-certified and **not** production-approved.
- Exit 2: `RELEASE_HOLD` because required operator evidence incomplete or failed.
- Exit 4: invalid/untrusted archive, filesystem or argument error; fail closed.
- With `--expect-hold`, CI gets exit 0 **only** when an intentionally empty evidence directory remains `RELEASE_HOLD`; a completed packet returns exit 3.

The most advanced possible result is only `READY_FOR_INDEPENDENT_REVIEW`. It is trivial for an operator to fabricate reports and calculate matching hashes; thus independent witnessing, real-device retesting and a separate authenticated human signoff are required. SHA-256 detects tampering against a **pretrusted hash**, not authorship or physical provenance. The G6 tool explicitly returns `physical_hardware_independently_verified=false`, `production_approved=false` and `commercial_release_allowed=false` even for a complete packet.

### CI scope

17 synthetic-only security/unit cases run before the expensive Godot builds; real V1–V18/G1–G4 native suite, Windows x64 / WebGL exports, Chromium real-client desktop/mobile emulator QA, RU/EN portal and G5 secure packaging/staging continue unchanged. After packaging a **real** source-bound G5 archive from the exact CI commit, G6 validates the real archive with an **empty** private evidence folder and demands `RELEASE_HOLD`. Only the non-sensitive summary is eligible for artifact retention. No real hardware validation is claimed by CI.

### Global gates remaining

G7: at least 20 consenting human players across all three acts, accessibility and qualitative independent art/audio review, record witnessed bug reports and repairs. G8: commercial rights, privacy/security review, Windows signing, trusted distribution, actual staging/CDN/rollback and authorized human GO. G9: support tickets, opt-in crash reporting, release incident drills, 30/60/90-day monitoring. Do not invent users, devices, benchmarks, sales or worldwide reach.

**Overall status: ENGINEERING DEVELOPMENT / PRODUCTION HOLD. Do not merge G6 or publish to master/prod without independent G6–G8 acceptance.**
