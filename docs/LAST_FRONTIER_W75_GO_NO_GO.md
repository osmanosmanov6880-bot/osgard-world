# LAST FRONTIER W75 — Release Readiness / strict no-invented-evidence protocol

**Date:** 28 Oct 2026 | **Workstream:** Playtest and quality validation | **Production status:** HOLD

## What is truly already implemented

- W71 five-step original spatial mission: [3/3 CI PASS](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40632289573).
- W72 three original native physical station mechanics: [3/3 PASS](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40643784751).
- W73 seven actual head-camera physics RayCast3D targets, G tools, bounded offline save/replay and anti-corruption: [3/3 PASS](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40646206165).
- W74 original live 3D material/servo response, real analog controller event route, local p95 frame interval diagnostics, eleven Godot suites and two source-authentic Chromium playthroughs: [3/3 PASS](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40650956529). Exact SHA `73ef81b54cb42831cafd9ac8fa69c5807cd8dc8d`.

No part of W75 modifies those gameplay rules, controls, textures, saved-game algorithms or previous accepted test suites.

## Actual W75 deliverable

`tooling/last-frontier/w75/release_gate.py` is a fully offline, version-pinned Python 3 standard-library release-evidence auditor with a blank manifest template, automatic SHA-256 file verification, real-game source linkage, privacy-preserving anonymous session inputs, independently observed device measurements, actual original art/rights/legal review signatures and explicit owner GO.

The audit does **not** claim to have already performed 12 real playtests or physically tested iPhone/Android/Windows GPUs. Blank manifests and synthetic test fixtures always produce `PRODUCTION_HOLD` and **nonzero exit status 3**, so software pipelines cannot accidentally publish.

The output is not a colorful confidence score. It is a per-check machine-readable release gate showing:

1. **Build authenticity:** exact original W74 Git SHA, accepted CI run, original exact-source audit fields, actual bytes of WebAssembly and PCK matching the genuine Godot export manifest.
2. **Human sessions:** >=12 distinct first-time consented, anonymized, externally observed sessions, evidence local SHA, >=9 completions, median 10–15 minutes and average <=2 confusion events.
3. **Physical platform:** real Windows desktop, Android and iOS devices with original source SHA, at least 300 frame measurements each, >=60 median observed FPS and <=20ms p95 frame time (strict *targets*, not existing achievements).
4. **AAA art and original rights:** independent environment, animation, audio, narrative and original asset licensing attestations.
5. **Brand / legal:** distinctive commercial name and documented jurisdiction/trademark and audio/art licenses. LAST FRONTIER is only the uncleared working title.
6. **Human release permission:** explicit signed owner authorization. A program can never make this decision.

If and only if every evidence field and threshold passes, the tool returns **`FINAL_MANUAL_REVIEW_REQUIRED`** and exits 0, never `RELEASE_APPROVED`. There is no automatic deploy/merge, no GitHub write token and no publishing. Independent reviewers must inspect authenticity of submitted observations and approve go/no-go outside the program.

## Protection and test evidence

Adversarial stdlib `unittest` QA covers no-uploads, duplicate participants, 12 synthetic fake participants, impossible results, invalid file digests, symlinks and traversal, fake source, fake self-matching audit JSON, missing Godot binary, absent hardware and art/license approval, accidental owner consent and malformed inputs.

Exact W74 ancestor SHA and every original W63–W74 gameplay/test/source asset file are protected byte-by-byte by CI. W75 can change only the offline auditor, unit tests, QA README, this product document and workflow file. New CI reports **software safety of the gate**, never certification of people or a commercial AAA release.

## Work remaining before a legitimate AAA claim

- Genuine time-stamped player sessions in the target locales on the actual code build.
- Physical PC/Android/iOS playability and sustained FPS on representative hardware.
- Professional production-authored 3D models and animations and expert art signoff, original score/VO plus rights.
- Accessibility studies with real players, including controller hardware and reduced-motion usability.
- Real trademark/name clearance and commercial publication signoff.

**NO master merge / NO public retail launch / NO game-as-AAA claims** until these exist as independent evidence.
