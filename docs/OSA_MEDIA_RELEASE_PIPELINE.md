# OSA media-release pipeline

Snapshot date: 2026-10-15

## Current inventory facts

- 31 registered assets: 19 video, 9 audio and 3 image.
- 28 asset IDs match the current Runway recent-assets listing. Three IDs are absent from that recent list but are still present in the canonical osa-global-intelligence media manifest. That manifest is an ID/metadata registry, not a binary archive; the original files must be recovered from the authenticated Runway workspace/archive and verified by bytes/MIME type. These three IDs are not treated as confirmed lost.
- 7 audio assets are reported by Runway as kind "image" although their source path extension is ".mp3". The manifest records this discrepancy without saving temporary URLs; actual file bytes and MIME type must be confirmed after export.
- 0 permanent URLs and 0 assets ready for publication.

## Files and responsibilities

- public/osa-library/media-inventory.csv is the detailed, human-maintainable inventory.
- public/osa-library/media-manifest.json is the machine-readable release view. It stores stable asset IDs, safe descriptive metadata, source discovery status, publication metadata and blockers; it deliberately omits temporary source URLs.
- scripts/osa-media-release-preflight.mjs validates CSV/manifest consistency, type metadata, URL policy, rights/QC states, publication blockers and the copy placed in dist/osa-library/.
- /osa-library/ displays the current blockers and links to the manifest.

## Release sequence

1. Resolve the three legacy IDs against the canonical OSA manifest and retrieve the original binary from the authenticated Runway workspace/archive. Preserve the stable ID and verify the actual downloaded bytes; the text manifest alone does not contain the binary.
2. Export chosen originals from Runway and move them to durable storage under a project-controlled HTTPS URL. Temporary CloudFront gallery URLs and _jwt links are forbidden in source control.
3. Record measured duration and MIME type from the actual file; do not trust a provider's generic kind field where it conflicts with the file extension.
4. Record language or an explicit non-linguistic value, and add subtitle/transcript paths where needed.
5. Confirm rights/usage constraints and a visual/audio quality check before setting rights_status=cleared, qc_status=passed and publication_status=ready.
6. Verify public URLs return the expected content type and byte-range support where required; then browser-test load, seek, resume, mobile playback, captions/transcript and error recovery.
7. Run npm run qa:osa-media-release for the standard gate. Before deliberately activating media, run node scripts/osa-media-release-preflight.mjs --check-dist --strict-ready and require zero blockers.

The strict-ready option is intentionally not used in normal CI yet, because all 31 source assets are currently blocked. CI verifies the gate while the reading and interactive courses remain usable without fake media controls.

## Scope boundary

This registry covers cinematic source assets and publication readiness; it does not claim that the 31 assets are complete lecture recordings. Do not auto-wire B-roll, music beds or trailer voiceovers as complete lecture versions. The eight lesson entries in src/osaMediaCatalog.ts remain unpublished until each lesson has its own approved, durable, playable source.


## Local original-file audit

Do not commit large original MP4/MP3 binaries to Git. Create a local osa-media-staging directory (ignored by Git) and export originals as asset-ID.extension so each file remains traceable to its stable Runway asset ID.

1. Run node scripts/osa-media-file-audit.mjs --root ./osa-media-staging --write-report ./osa-media-staging-report.json to inspect whatever has been recovered so far.
2. The audit checks file-signature bytes against extension and inventory kind, calculates SHA-256 and file size, and uses ffprobe to verify a real audio/video stream and measured duration. The provider's generic kind field is not trusted in place of file bytes.
3. Review warnings for source-extension discrepancies; correct the inventory only after confirming the actual file. Record measured duration/language and update rights/QC metadata through the release process.
4. node scripts/osa-media-file-audit.mjs --root ./osa-media-staging --strict is the deliberate launch-preflight mode. It returns non-zero while any source file is missing, its bytes/type/duration are invalid, or publication metadata is not cleared.
5. npm run qa:osa-media-files runs built-in signature tests in ordinary CI. It does not require source binaries and does not claim that production playback is active.

The report is an audit aid; it does not upload binaries, assign rights, publish URLs or override the publication manifest's blockers.
