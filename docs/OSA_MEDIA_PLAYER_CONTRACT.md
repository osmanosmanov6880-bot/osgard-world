# OSA media-player contract

Updated: 2026-10-15

## Current release truth

The OSA learning catalogue has eight detailed bilingual lesson pages and an interactive eight-scene course. Their reading/practice experience is published. The original media inventory has 31 asset records, but it has no permanent URLs; signed Runway gallery URLs are temporary and must not be committed as production sources. The audio/video player therefore remains hidden until a lesson has a durable playable file.

## Implementation in this branch

- src/osaMediaUrl.ts accepts same-origin public paths or HTTPS URLs and rejects protocol-relative URLs, credentials, HTTP, and known temporary-signature query parameters.
- src/osaMediaCatalog.ts provides one typed attachment point for audio, video, locale, duration, captions and transcript for each lesson. Sources intentionally remain null until permanent hosting is configured.
- src/OSAMediaPlayer.tsx supports play/pause, seeking, volume, speed (0.75×–2×), playback-position restoration, captions and transcript when those resources exist. It provides accessible error states and never displays controls for a missing asset.
- /lectures/:slug and /osa-cinema resolve their media from the shared catalogue rather than inventing URLs or duplicating media metadata.
- scripts/osa-media-player-smoke.mjs checks URL safety, media wiring and the missing-media contract.

## Publication gate still required

1. Export and review the original approved media from Runway.
2. Host approved files at durable project-controlled HTTPS URLs with range-request support.
3. Populate src/osaMediaCatalog.ts with permanent sources, measured duration, language, transcript/captions and rights status.
4. Verify every file returns the expected content type and supports mobile playback.
5. Test the playback/seek/resume/caption flow in a browser, then record the deployment SHA and live route verification.

This implementation does not claim that audio or video is already available for the eight lessons. The current reading course remains usable while the media release is pending.

## Monetization boundary

Keep the introductory interactive course free while validating demand. A paid one-time mini-course is the first pricing experiment after its complete media and practical deliverables are ready; sample price bands (€9–19 for a starter, €29–59 for a complete practice-led pack) are hypotheses, not market facts. Do not enable real payments until a seller-eligible provider, server-side order/access storage, signed-webhook verification, idempotency, refund/cancellation and test-mode end-to-end checks are implemented.
