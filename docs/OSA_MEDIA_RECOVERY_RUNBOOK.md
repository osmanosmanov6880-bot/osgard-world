# OSA media recovery runbook

Updated: 2026-10-15

## Verified state

- Canonical source: https://github.com/osmanosmanov6880-bot/osa-global-intelligence
- Reference snapshot: https://github.com/osmanosmanov6880-bot/osa-global-intelligence-2
- Manifest: `public/interactive-cinema/media-manifest.json`
- Assets listed: 31 (19 video, 9 audio, 3 images).
- Assets with permanent URLs: 0.
- Current production truth: interactive course is published; playable hosted video course is not connected.

## Recovery sequence

1. Open the authenticated Runway workspace: https://app.runwayml.com/ .
2. Search each `asset_id` in `media-inventory.csv`; download originals where available. Record missing, duplicated, alternate, and unusable assets instead of silently substituting them.
3. Review rights, language, duration, resolution, and editorial fit. Select the intended sequence across the three acts.
4. Upload approved originals to a permanent HTTPS host/CDN controlled by the project. Do not use temporary signed links.
5. Update the canonical manifest's `permanentUrl` values and add metadata (duration, language, captions, license/rights, checksum) before release.
6. Integrate a real accessible video/audio player in the canonical app. Add captions/transcript, keyboard controls, responsive behavior, loading/error states, and graceful fallback.
7. QA each media URL (HTTP success, content type, range requests, mobile playback, captions, rights), run the project test suite, then publish.
8. Change the release status only after production playback is verified.

## CSV columns

`kind, slug, role, asset_id, permanent_url, status, source_repository`

The CSV is generated from the primary manifest. An asset ID is an identifier, not a playable URL. `NOT_HOSTED` means the manifest has no permanent URL; it does not prove the source is deleted from Runway.

## Hard blocker

This repository connection can inspect and update GitHub, but it does not provide authenticated access to the Runway asset gallery or the original media bytes. Therefore original files cannot be recovered or hosted automatically from IDs alone. Continue with the authenticated workspace and approved exports; never fabricate media URLs.
