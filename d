# OSA media recovery runbook

Updated: 2026-10-15

## Verified state

- Canonical source: https://github.com/osmanosmanov6880-bot/osa-global-intelligence
- Reference snapshot: https://github.com/osmanosmanov6880-bot/osa-global-intelligence-2
- Manifest: `public/interactive-cinema/media-manifest.json`
- Manifest inventory: 31 assets (19 video, 9 audio, 3 images).
- Permanent URLs in the manifest: 0.
- Runway connection: authenticated and verified on 2026-10-15; the recent-assets view returned 31 items.
- Exact manifest-ID matches in the recent Runway listing: 28 of 31 (18 videos, 7 audio assets, 3 images).
- Manifest IDs not found by exact ID in that recent listing: `a0d3d701-8893-40a5-a064-71c934e73a8d` (video), `db58afba-0d6d-4ca4-946d-90eb1a7791da` (trailer voiceover), and `b85171e3-8d86-47de-b65a-7f955a25dd9a` (alternate trailer voiceover).
- Absence from the recent-assets response is not proof that an asset was deleted. The gallery also contains similarly named audio under different IDs; do not silently substitute it for an exact manifest ID.
- Production truth: the interactive course is published. The hosted, playable video/audio course is not connected yet.

## Recovery sequence

1. Use the authenticated Runway workspace to locate the three IDs that did not appear in the recent listing. Confirm alternatives by listening/viewing, not by name alone.
2. Review each exact-match asset for content, language, duration, resolution, accessibility, licensing/rights, and editorial fit. Select the intended sequence across Acts I–III.
3. Export/download approved original files from Runway and upload them to permanent HTTPS storage controlled by the project. Do not use signed temporary URLs as production `permanentUrl` values.
4. Update the canonical manifest with durable URLs and metadata (duration, language, captions/transcript, rights, checksum, and publication status).
5. Integrate an accessible audio/video player in the canonical app and OSGARD entry point. Support keyboard controls, mobile layout, loading/error states, playback resume, captions/transcript where available, and an interactive-course fallback.
6. QA every media URL (HTTP success, correct content type, range requests, mobile playback, captions, rights), run the project test suite, then publish.
7. Change the release status only after production playback is verified.

## CSV columns

`kind, slug, role, asset_id, permanent_url, status, source_repository`

- `FOUND_IN_RUNWAY_NOT_PERMANENTLY_HOSTED`: exact ID present in the recent Runway listing; no durable URL is published.
- `NOT_FOUND_IN_RECENT_RUNWAY_LIST`: the ID did not appear in this listing. This does not imply deletion.
- `permanent_url` stays blank until the file is placed in permanent project-controlled hosting.

## Current blockers

- The Runway connector can inspect recent assets, but it does not expose a bulk export/download action or a permanent storage destination for the portal.
- All 31 manifest records still have `permanentUrl: null`; signed CDN links expire and must not be committed as durable URLs.
- Production video/audio playback therefore remains blocked until file export and permanent hosting are completed.
