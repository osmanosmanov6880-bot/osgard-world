# OSA CINEMA V28 - private final media intake

## What this actually solves

The V24 full-decoding QC expects a PRIVATE_FINAL_MASTER_MANIFEST.json with four exact MP4/VTT SHA256 hashes, source identities and codec/duration metadata. V28 calculates this manifest from four actual final candidates locally; editors no longer need to hand-type hashes or probe data. It never uploads a film, approves rights or edits a public catalogue.

## Required private structure

Use one private owner-controlled directory, not the GitHub repository:

    PRIVATE_DIR/
      masters/osa-v15-directors-ru.mp4
      masters/osa-v15-directors-en.mp4
      masters/osa-v15-trailer-ru.mp4
      masters/osa-v15-trailer-en.mp4
      captions/osa-v15-directors-ru.vtt
      captions/osa-v15-directors-en.vtt
      captions/osa-v15-trailer-ru.vtt
      captions/osa-v15-trailer-en.vtt

These are LOCAL final candidate file names, not evidence that a candidate is final or licensed. The directory must contain exactly these eight media files. Copy approved candidate material to this workspace, rather than renaming original V16/V18 sources in place.

## Run on owner machine

    node scripts/osa-cinema-v28-final-intake.mjs --root PRIVATE_DIR --originals docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json --out PRIVATE_QA_REPORTS/V28_FINAL_MASTER_MANIFEST.json
    node scripts/osa-cinema-v24-final-master-qc.mjs --root PRIVATE_DIR --plan PRIVATE_QA_REPORTS/V28_FINAL_MASTER_MANIFEST.json --originals docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json --report PRIVATE_QA_REPORTS/V24_FINAL_QA.json --strict-technical

The report directory MUST be outside PRIVATE_DIR. V28 will not overwrite existing reports. File symlinks and unexpected extra files are rejected. FFprobe verifies one H.264 video and one AAC audio stream, dimension/duration bounds; WebVTT checks formatting/timing/reading speed. V24 goes further by fully decoding every MP4.

## Mandatory human review and launch blockers

`audioLanguageClaim` is a NAME-derived expectation, NOT speech recognition. Reviewers must hear all RU and EN tracks, compare with scripts, approve the exact final edit, synchronize and review all VTT cues, and verify all commercial source rights. Independent rights counsel, real production HTTPS and device QA, publisher's release-hash authorization and rollback are still missing. V28 never creates a GO decision, streaming URL or paid access.

## Executable CI

    node --test scripts/osa-cinema-v28-final-intake.test.mjs

The 8-test suite generates four actual synthetic H.264/AAC MP4s and four WebVTT files, derives manifest hashes, passes the manifest to V24 and checks exact-file safety and negative cases. These fixtures are not user-owned commercial film assets.
