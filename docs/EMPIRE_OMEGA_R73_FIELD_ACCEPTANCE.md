# EMPIRE Omega R73 - manual 40-mission evidence and release gate

Date: 2026-10-25. Source-bound tool: scripts/omega_r73_field_qa.py

## Why this exists
R55 currently tests forty mission transitions and primary/backup saves inside the real Godot runtime by invoking documented events. R63 checks wiring of real game actions. Neither substitutes for a complete human playthrough. R73 refuses to claim one without original evidence.

## Steps
1. On the published source branch generate an empty source-pinned template:
   python3 scripts/omega_r73_field_qa.py --template --output campaign-session.json
2. Check source_commit against the uncached public release.json and deployment record.
3. Record one genuine continuous desktop or mobile session from mission 1 through 40 as campaign.webm or campaign.mp4. Disclose real human operator, UTC date, platform and video duration. Document pauses and retries.
4. Capture 40 real PNG frames, one at the end of each mission, and fill exact start_s / finish_s recording offsets, original action, reward and passed result.
5. Reload game progress after missions 6, 20 and 40, supply three independent checkpoint PNG frames, verify mission stage persisted.
6. Compute actual SHA-256 for the video and each frame. Do not reuse sample digests.
7. Verify: python3 scripts/omega_r73_field_qa.py --verify campaign-session.json --evidence-dir . --output field-verdict.json
8. Independent reviewer must view full recording and each screenshot, check correct gameplay and saves, and separately inspect hardware and visual quality.

## Mandatory independent release gates
- R50/R71/R72 public hash and authentic desktop + emulated touch browser checks at exact source.
- Physical Android and iPhone video with p95/p99 frame metrics, build source and device identification.
- Twenty genuine user sessions, camera/controls, resumed games and crash recovery.
- Artistic review of real Godot frames and asset licences, backed by measurements.
- Separate final written human GO approval.

## What R73 can and cannot certify
Checks forty sequence steps, 43 distinct PNG file names, PNG headers/dimensions, file hashes, UTC timestamps, interval order, checkpoint numbers, original action and reward mapping, and source commit. It DOES NOT inspect frame contents, decode full video, witness actual hardware, or rate AAA quality. Even when all fields pass, output is EVIDENCE_READY_FOR_INDEPENDENT_REVIEW, production_go=false. The empty template is not evidence.
