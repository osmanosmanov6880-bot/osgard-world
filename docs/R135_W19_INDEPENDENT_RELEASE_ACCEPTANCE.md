# OSGARD R135 W19 — Independent acceptance and promotion

This is a **software-only Godot 4.4.1 WebGL candidate**. A green Godot native import or
rendered greeting is necessary but not sufficient for production. **Never automatically
change** `scripts/r135-active-release.json` by merging the artwork/onboarding PR.

## Isolated tracks

1. Source branch: `feat/r135-approved-aaa-luxury-russian-onboarding-20261025`.
   Native acceptance and full optimized WebGL must be green on the exact same SHA.
2. Independent acceptance branch: `release/r135-w19-independent-gate-20261025`.
   Negative tests are contract-only; green contract tests do **not** accept binaries.
3. An additional, explicitly reviewed release pin is required:
   `scripts/r135-w19-release-pin.json`. Pin exact SHA, successful WebGL run,
   artifact ID, manifest and archive SHA-256, and 13 original screenshots.
4. Only after actual image inspection set booleans attesting desktop/mobile
   composition, zero UI overlap, RU/EN, and three authentic diagnostics.
   Never set these to true merely because another pipeline was green.
5. Stage the exact reviewed ZIP with `scripts/r135-release-stage.py`, and then
   revalidate Godot binaries, fresh Nginx HTTP behavior, correct WebAssembly MIME,
   range requests, gzip, and original-image luminance.

## Create a checksum-only pin draft (never self-approved)

After the entire W19 Godot WebGL run succeeds, download its exact named
artifact and run:

```bash
python3 scripts/r135-w19-candidate-pin-draft.py \
  --artifact /path/to/extracted-actions-artifact \
  --source EXACT_40_CHAR_COMMIT_SHA \
  --run-id ACTUAL_SUCCESSFUL_RUN_ID \
  --artifact-id ACTUAL_ARTIFACT_ID \
  --output /tmp/r135-w19-pin-UNREVIEWED.json
```

The script requires the completed W10 evidence and computes hashes of
the exact WebGL ZIP, manifest and 13 genuine PNG files. It deliberately
sets all approval flags to **false**. Inspect the original images and
browser playthrough, then explicitly attest only supported results in
`scripts/r135-w19-release-pin.json` on
`release/r135-w19-reviewed-artifact-20261025`. The independent
acceptance workflow runs automatically on this review branch; an immutable
non-production GitHub Release is created only after its full acceptance
job succeeds.

The public W18 channel stays selected even when a W19 candidate Release
exists. Production requires a separate protected selector update and live
SSH verification.

## Strict visual acceptance

Original frame hashes, never redrawn/generated PNGs:

- `w19-desktop-1366-russian-luxury-welcome.png`
- `w19-mobile-390-russian-luxury-welcome.png`
- `w17-desktop-ru-operator.png`, `w17-mobile-ru-operator.png`
- `desktop-1366.png`, `w6-portrait-optical-active.png`
- `w8-hud-360x780.png`, `w8-hud-430x932.png`,
  `w8-hud-932x430.png`
- `w12-desktop-1366-fault-2-active.png`,
  `w12-desktop-1366-fault-3-active.png`,
  `w12-mobile-390-fault-2-active.png`,
  `w12-mobile-390-fault-3-active.png`

The independent Python checker rejects missing PNGs, malformed CRC,
wrong hashes, duplicate frames, a wrong version/source, manipulated ZIP members,
incorrect diagnostics, fake hardware FPS and premature AAA claims.

## Production HOLD until

- Both the new native and full WebGL runs are successful on one immutable SHA.
- Independent human visual review of original screenshots, plus screenshot hashes,
  captured directly from the genuine browser build.
- Successful full independent W19 acceptance run (not only negative tests).
- Protected staging and SSH publication adapted **explicitly** for W19 with a
  verifiable deployment pin, W18 retained and W14 rollback still available.
- New live HTTP and playable three-case smoke after any promotion.

The active **W18** production selector remains unchanged in this branch;
the independent verified **W14** rollback must not be overwritten.

**Not certified:** physical iPhone/Android GPU thermals, 8K output, or
cinema-grade AAA photorealism. Software Chrome SwiftShader screenshots do not
prove any of these. Engineering controls are game simulation only.
