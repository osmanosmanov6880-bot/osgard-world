# OSA media-release pipeline

Snapshot date: 2026-10-15

## Current inventory facts

- 31 registered assets: 19 video, 9 audio and 3 image.
- 28 asset IDs match the current Runway recent list; 3 do not currently match and require recovery from the source repository or workspace archive.
- 7 audio assets are reported by Runway as kind "image" although their source path extension is ".mp3". The manifest records this discrepancy without saving temporary URLs; actual file bytes and MIME type must be confirmed after export.
- 0 permanent URLs and 0 assets ready for publication.

## Files and responsibilities

- public/osa-library/media-inventory.csv is the detailed, human-maintainable inventory.
- public/osa-library/media-manifest.json is the machine-readable release view. It stores stable asset IDs, safe descriptive metadata, source discovery status, publication metadata and blockers; it deliberately omits temporary source URLs.
- scripts/osa-media-release-preflight.mjs validates CSV/manifest consistency, type metadata, URL policy, rights/QC states, publication blockers and the copy placed in dist/osa-library/.
- /osa-library/ displays the current blockers and links to the manifest.

## Release sequence

1. Recover the three not-found assets, preserving their exact IDs and verifying the actual downloaded bytes.
2. Export chosen originals from Runway and move them to durable storage under a project-controlled HTTPS URL. Temporary CloudFront gallery URLs and _jwt links are forbidden in source control.
3. Record measured duration and MIME type from the actual file; do not trust a provider's generic kind field where it conflicts with the file extension.
4. Record language or an explicit non-linguistic value, and add subtitle/transcript paths where needed.
5. Confirm rights/usage constraints and a visual/audio quality check before setting rights_status=cleared, qc_status=passed and publication_status=ready.
6. Verify public URLs return the expected content type and byte-range support where required; then browser-test load, seek, resume, mobile playback, captions/transcript and error recovery.
7. Run npm run qa:osa-media-release for the standard gate. Before deliberately activating media, run node scripts/osa-media-release-preflight.mjs --check-dist --strict-ready and require zero blockers.

The strict-ready option is intentionally not used in normal CI yet, because all 31 source assets are currently blocked. CI verifies the gate while the reading and interactive courses remain usable without fake media controls.

## Scope boundary

This registry covers cinematic source assets and publication readiness; it does not claim that the 31 assets are complete lecture recordings. Do not auto-wire B-roll, music beds or trailer voiceovers as complete lecture versions. The eight lesson entries in src/osaMediaCatalog.ts remain unpublished until each lesson has its own approved, durable, playable source.
