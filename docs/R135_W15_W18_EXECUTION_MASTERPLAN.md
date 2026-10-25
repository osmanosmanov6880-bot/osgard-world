# OSGARD R135 — execution through W18 (large release blocks)

Updated 2026-10-25. This is a source-and-evidence acceptance contract, not a declaration of AAA quality.

## A. W14 controlled publication
- W12–W14 game code merged through PR #393. Do not merge the old stacked PRs #364/#370/#386.
- W14 exact source 4d1aec6c5f59f07d4f6bf1c4b97a46379d9d7d9e, manifest hash 4a2333a8fdaef0da270a224b85ee8a763170f923f2449635018a74626398d05b, original ZIP hash 704131eda3a1ba1c3a860690c7f2beb0115bae65d818fc7887c0cb44b9817245, recorded Actions #40175524463.
- PR #397 is a separately gated production promotion. Required: green checks on current reconciled head, W14 immutable candidate verified, actual browser screenshot review, Nginx WASM gzip and PCK 206, protected SSH, exact live source/version/hash and verified W11 rollback.
- Publishing source code is not publishing a game. Do not claim W14 live until the production manifest proves it.

## B. W15 industrial environment
- Implement 3 bounded batched detail groups / 47 instances, with two unchanged W7 floor batches / 18 grids and <=8 single mesh nodes.
- Real ECO and HERO physical material differences without adding new shadow lights or gameplay collisions. Original R135 PBR GLBs, original 36 texture sources and optical fill remain intact.
- Required original WebGL screenshots: desktop 1366x768 / 1920x1080; portrait 360x780 / 390x844; landscape 932x430. Inspect reflections, typography, 3D caption viewports, button usability and reduced-motion. Bright-pixel counts are not artistic-quality certification.

## C. W16 authorized physical device matrix
- Eight combinations: Android Chrome or real iPhone Safari x portrait or landscape x ECO or HERO. Minimum two independent sessions each, with independently reviewed original screenshots and real touch sequences.
- Collect raw visible-page rAF callback intervals, sampled Godot FPS, immutable binary SHA, test-device OS/browser/build, orientation, 60s or longer samples and multi-minute thermal/battery observations separately.
- W16 structural validator exists in scripts/r135-hardware-matrix.mjs. Its fixtures are synthetic and do NOT certify a phone. No physical records currently supplied; status HOLD_DEVICE_EVIDENCE_MISSING.
- The existing Android Chromium CDP tool is NOT an iPhone Safari capture. Any Safari results need a separate authorized Safari/Web Inspector hands-on procedure. User attestation and UA strings are not cryptographic proof.
- Agree quality budgets BEFORE qualifying measurement; do not recategorize failures. Report GPU frame times or touch latency only if independently measured with appropriate tooling.

## D. W17 RU/EN onboarding and accessibility
- New in-game language switch, L-key shortcut, localized eight core action buttons, mission readouts, fault labels, simulation warning, English fallback. No change to simulation controls or local progress schema.
- Test real Chromium keyboard/touch RU and EN toggling and three diagnostic faults. Preserve real keyboard focus, 44px-equivalent touch targets where possible, visible text and reduced-motion usability. Inspect 360px mobile for overlap.
- Real equipment work requires trained authorization, isolation/lockout and verified zero energy. This game is a SIMULATION, not an industrial maintenance procedure.
- Prior to product claims, user sessions must establish first-success time, failure comprehension, fault-case completion and retention, with raw non-identifying evidence and privacy controls.

## E. W18 separate immutable public game release
- Cut a new source SHA AFTER W15/W17, never silently replace W14 ZIP. Build native Godot 4.4.1, original HERO/ECO, three real interactive simulated faults, deterministic save migration and locale QA.
- Produce new version, immutable browser WebGL ZIP and manifest with actual source SHA + every file's SHA-256, reviewed original desktop/mobile frames, Nginx MIME/gzip/206 proofs and independent re-download/verify.
- Security/frontend/adjacent-game matrix and production SSH must be green. Activate atomically and verify real live manifest/route before declaring released; rollback to previously pinned W11 or W14 on any failure.
- Distinguish software release acceptance from external phone performance, actual iPhone usability and AAA/8K/photorealism artistic claims.

## Completion flags
IMPLEMENTED means code committed; CI_PASS means the exact commit passed actual tests; REVIEWED means original human QA; PUBLISHED means public HTTPS source/manifest hashes are verified; DEVICE_ACCEPTED means independent physical mobile evidence. Missing proof always means HOLD.
