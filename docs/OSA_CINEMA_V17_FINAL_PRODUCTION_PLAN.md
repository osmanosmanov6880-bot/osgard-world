# OSA CINEMA — V17 media mastering, measured QC and film completion

**Date:** 25 October 2026. **Scope:** private workprint evaluation, not a public film release.

## Current product truth

- V15 interactive bilingual OSA CINEMA is publicly deployed and Chrome-tested.
- V16 real-source review, SHA-256 checks, private editor and MP4/MP3 release blockers are merged into GitHub master.
- V17 measures actual ten private sources, adds an independent offline QC desk and produces genuine private 239-second RU/EN narration-guide audio tracks.
- **No recorded feature film, soundtrack rights, reviewed captions, or full eight-scene licensed video course has been approved for public distribution.**

## BLOCK A — 10 originals and measured video/sound: delivered

The verified originals are 4 MP4 (RU/EN 45s previews and RU/EN 239s director workprints) and 6 mono MP3 narration tracks (acts I–III in RU/EN).

The new Python media QA program is scripts/osa-cinema-v17-av-qc.py. It verifies exact original byte counts and SHA-256, decodes each audio track, calculates EBU R128 integrated loudness/true peak, and records black, freeze and silence intervals from real FFmpeg decoding. Reference data with original hashes: docs/OSA_CINEMA_V17_OBJECTIVE_QC_20261025.json.

| Sources | Loudness (LUFS) | True peak (dBTP) |
| --- | --- | --- |
| RU/EN 45s preview | -13.6 to -13.9 | -0.5 |
| RU/EN 239s director edition | -13.7 to -13.8 | -0.5 to -0.4 |
| Six separately recorded act MP3 | -16.5 to -17.4 | -1.1 to -0.6 |

- Black transition near 00:23.83 lasts around 0.46–0.50s.
- Static holds near 00:00–00:05; in 239s editions also 01:19–01:21 and 02:37–02:39.
- Act narrations II/III contain occasional pauses around one second.
- Editorial **review indicators**, not automatic defects. Loudness normalization must follow the eventual delivery platform.

Reproduce locally with Python: scripts/osa-cinema-v17-av-qc.py --video-root PRIVATE_MP4_DIR --narration-root PRIVATE_MP3_DIR --report PRIVATE_QC.json --strict-integrity.

## BLOCK B — fully offline quality desk: delivered in code

Open tools/osa-cinema-v17-quality-desk.html as a local browser file; it contains the non-secret measurements for all ten sources and uses no network, remote scripts or uploads.

- Pick actual MP4/MP3 from the device, verify whole-file SHA-256.
- Browse true LUFS and dBTP, click black/static/silence markers to seek to the frame or timestamp.
- Keep editing notes with the measured timestamp and export them as a **private** JSON report.
- RU/EN controls; accessible buttons; desktop and 390px mobile testing.
- Export explicitly retains releaseAuthorized=false, rightsVerified=false, spokenLanguageVerified=false and finalCaptionsApproved=false.

Tests: scripts/osa-cinema-v17-quality-desk-smoke.mjs and scripts/osa-cinema-v17-quality-desk.spec.mjs.

## BLOCK C — separate real private guide narration tracks: delivered

Two real 239-second private AAC narration guides were assembled from the existing six MP3 sources WITHOUT altering either director workprint or its original audio.

The proposed three-act boundaries are based on observable image holds:
- Act I starts 00:05; RU narration ends 01:18.718, EN 01:13.911.
- Act II starts 01:19; RU narration ends 02:34.468, EN 02:29.844.
- Act III starts 02:37; RU narration ends 03:50.796, EN 03:46.486.

Both have real SHA-256, file sizes and 239.000-second duration recorded in docs/OSA_CINEMA_V17_PRIVATE_ACT_GUIDE_TIMING.json. **This is an unapproved alignment hypothesis; a real human editor must listen and approve the matching scene.**

Regenerate from the exact private MP3 originals with:
- python3 scripts/osa-cinema-v17-build-private-guide-audio.py --check-plan
- python3 scripts/osa-cinema-v17-build-private-guide-audio.py --audio-root PRIVATE_MP3_DIR --out-root PRIVATE_GUIDE_DIR

Code always verifies input byte hashes, refuses missing substitutes and retains PRIVATE / NOT PUBLISHED status.

## BLOCK D — legal, spoken-language and creative sign-off: NOT complete

For every exact 4 MP4 / 6 MP3 source SHA-256, obtain actual commercial-usage rights documentation, perform on-ear RU/EN speech and music review, compare with approved script, evaluate known freeze/black points, and record final editorial decision. Filename "final", metadata "und" and a technically valid MP4 cannot be used as evidence of language or rights.

## BLOCK E — actual master pictures, mixes and captions: NOT complete

After approval, build separate RU/EN final audiovisual masters, preserve stems and original audio, finalize sound loudness/peak according to hosting platform requirements, and create real speech-synchronized RU/EN WebVTT with checked text and credits. An empty VTT skeleton or guessed transcript is not a publishable subtitle.

## BLOCK F — permanent streaming, independent acceptance and commercial launch: NOT complete

Upload only rights-cleared masters to stable HTTPS with correct MIME and byte-range response. Then reconcile media inventory, catalog and player with genuine audio, video, language and subtitle paths. Test playback, buffering, seek, errors, range, slow network, mobile and accessibility in real production Chrome. Deploy only from the guarded newest master, preserving other OSGARD apps. Run actual viewer pilot before offering paid video content.

### Closure record

- [x] Published interactive V15, real production browser QA.
- [x] V16 source provenance and local human-review pipeline merged.
- [x] Four MP4 and six MP3 fully measured by FFmpeg.
- [x] Two new, real, private 239s narration guide tracks assembled.
- [ ] Merge V17 only after QA and browser tests succeed.
- [ ] Real rights/editorial/voice/subtitle proofs and signed approval for each source.
- [ ] Final licensed RU and EN mixes, actual timed captions, permanent media delivery.
- [ ] Genuine recorded film publicly played and independently accepted.

This makes the **remaining tasks verifiable**, but does not pretend to have completed external legal/editorial work.
