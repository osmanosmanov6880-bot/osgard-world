# OSGARD W56 — Independent Device Evidence Review (production HOLD)

W56 provides a local, **fail-closed** JSON review helper. It never automatically authorizes publication, merges, domain changes, remote industrial-machine actions or physical GPU certification.

## Source parity

Every local report must name the **exact proposed source commit SHA** supplied to the --expected-sha argument. A green W48–W54 runner on source 1deb7581 cannot prove current W55 staging 5a39cdf physical performance. Never copy artifacts from a different SHA or claim that an emulator is a real phone.

## Inputs and limitations

- Windows: output from an offline PowerShell EXE/PCK preflight. This compares two SHA-256 values, launches the real candidate, reads GPU model/driver if Windows exposes it, and records manual operator checks. No FPS is measured by the preflight.
- WebGL: an offline localhost browser test reads genuine Godot Engine and RenderingServer read-only counters in HERO and ECO. It requires at least 10 samples spanning 20 seconds with frame progression for both modes. A GPU name is not proof of actual physical hardware or 1% low FPS.
- Android/iPhone: separate first-hand manual observations. JSON must carry platform, source SHA and actual touch, typography, HERO/ECO and crash status. A phone emulator is not real device acceptance.

All reports are user-provided and untrusted. The CLI refuses malformed, missing or contradictory evidence. Even if every report looks internally consistent, status is **HOLD / HUMAN_HARDWARE_REVIEW_REQUIRED**. An independent engineer must verify real devices, first-run user experience, long-session frametimes, 1% low FPS and thermals, RU/EN typography, privacy and accessibility, and the exact intended release.

## Local execution

Python 3 standard library only; no network, dependencies, keys, token or credentials.

Run:

    python tooling/osgard-w56/hardware_review_gate.py --expected-sha ACTUAL_40_CHAR_RELEASE_SHA --output osgard-w56-review.json
    python -m unittest discover -s tooling/osgard-w56 -p test_hardware_review_gate.py -v

Add --windows report.json, --webgl report.json, --android report.json and --ios report.json for actual self-reported evidence. The helper will NOT certify physical hardware, even on four supplied successful reports.

## Acceptance strategy

1. W48–W55 exact-head full CI and source-attested artifact must pass; standalone W55 GitHub screenshot artifact alone is insufficient.
2. Use the original candidate EXE/PCK and WebGL matching that same final HEAD, independently verify SHA-256 before testing, and run physical Windows/GPU plus target phones.
3. Record actual median and 1% low FPS with an appropriate frame-timing tool, 30-minute thermal stability, six actual missions and real touch, font fallback and safe-area checks. W56 browser ENGINE FPS is not 1% low FPS evidence.
4. Have a human review original screenshot pairs, device evidence and an actual rollback rehearsal.
5. Resolve upstream W46/W47 staging PR chain and rerun integration checks on the proposed master merge commit. Make a separate, documented human GO decision. Until then **production HOLD**.

**Integration with W49:** this PR explicitly adds four allowed W56 paths to the W49 source contract and pins the exact Git blobs of the review CLI, its 12 adversarial tests, and the independent workflow. W49 now tests 32 negative cases (29 original + 3 W56), including rejection of incomplete or altered W56 evidence tooling. This cannot change W47 physical-simulation, mission, scene, WebGL game-driver or protected original assets.

**Scope of this PR:** source-only QA tools under tooling/osgard-w56, the dedicated CI workflow, and W49's narrow allowlist/regression tests. Native Godot scene, core, physics, geometry, missions and visual-quality modules remain untouched. It targets staging, not master; physical release remains HOLD.
