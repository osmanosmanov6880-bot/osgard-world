# OSGARD R135 W18 — independent production acceptance

## Why W18 is not the current public release
W14 is verified on the public server and its immutable prior release must remain a rollback candidate.
W15/W17 improvements live in feature PR #405. No W18 production game should be claimed from
source-only merge, an old W14 ZIP, an emulated phone, or a prettier unrelated image.

## Immutable evidence handshake

1. Build exact W18 game SHA from a green Godot 4.4.1 workflow: native mission/safety/save tests,
   actual desktop and emulated touch complete optical/airflow/interlock gameplay, W17 RU/EN
   on-screen feedback, original unmodified PNGs, optimized WebGL ZIP, real W11 luminance,
   Nginx gzip WASM/206 PCK and independent hashes.
2. Human inspect every W17/W15 viewport, especially real 360×780, 430×932, 932×430,
   original desktop/portrait RU screenshots, and each fault caption in the live rendered scene.
3. Create \`scripts/r135-w18-release-pin.json\` containing EXACT candidate source SHA,
   successful Actions run ID and artifact ID, archive/manifest SHA-256, and all 11
   independently reviewed original PNG SHA-256 values. No \`latest\` references.
   Fields: version, source_commit, artifact_run_id, artifact_id, artifact_name,
   archive_sha256, manifest_sha256, screenshots_sha256, reviewed_desktop,
   reviewed_portrait, reviewed_ru_en, browser_three_fault_cases,
   physical_phone_fps_verified = false.
4. Dispatch \`.github/workflows/r135-w18-promotion-gate.yml\` on release branch. It verifies
   exact successful source run and unexpired artifact ID, byte-identical ZIP and
   manifest, members, original screenshots, both three-fault reports, and actual Nginx delivery.
   A missing pin, missing image, replacement source commit or forged hardware claim is HOLD.
5. ONLY AFTER the independent promotion gate is green, prepare a separate protected production
   deploy PR with reviewed pin, byte-verified SSH deployment, exact live HTTPS manifest and
   unrelated-game route regressions. Do not add a production switch to this gate alone.
6. Roll back to immutable W14 or verified prior W11 if public acceptance fails.
   Preserve encrypted credentials, unrelated releases, and players' local v2 progress.

## Separate hardware acceptance (W16)
Real Android Chrome and iPhone Safari x portrait/landscape x ECO/HERO, two sessions per cell.
Independent hands-on tests and raw data are required. WebGL SwiftShader screenshots and
rAF callbacks are not real phone/GPU frametimes. W16 remains HOLD until physical reports.
AAA/photorealism claims likewise require independent artistic acceptance beyond brightness counts.

## Current status labels
- Test fixture/contract CI PASS = the verification code rejects certain forgeries, not game release.
- W18 browser/full native CI PASS = exact source candidate works in tested software configuration.
- W18 independent package promotion PASS = reviewed immutable binary and PNGs pass real Nginx.
- W18 public production PASS = SSH and real external HTTPS byte/version checks succeed.
- W16 DEVICE PASS = physical Android/iOS evidence and independent reviewer approval.
