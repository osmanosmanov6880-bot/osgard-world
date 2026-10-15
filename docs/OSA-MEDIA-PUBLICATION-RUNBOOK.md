# OSA Learning media publication runbook

## Scope

Eight canonical lessons, two locales (ru/en), and audio/video resources. A text lesson is not a published recording. A syntactically valid URL is not evidence that a media file exists or is accessible.

## Pre-publication checklist

1. Identify the exact lesson slug, locale and media kind for each file.
2. Verify rights and obtain explicit publication clearance.
3. Validate actual file bytes and codec using `npm run qa:osa-media-files` for signature self-tests and `node scripts/osa-media-file-audit.mjs --root <staging-directory> --strict` for staged assets.
4. Confirm measured duration, transcript or subtitles, and editorial quality review.
5. Upload approved files to durable HTTPS hosting; verify browser playback and HTTP responses for the exact production URLs. Do not use temporary signed links.
6. Set the approved resource in `src/osaMediaCatalog.ts` only after the preceding checks. Preserve all unpublished resources with `src: null`.
7. Run `npm run check`, `npm run qa:osa-media`, `npm run qa:osa-media-availability`, `npm run qa:lectures`, `npm run qa:osa-narration`, and `npm run build`.
8. Review CI checks and obtain approval before merging. Smoke tests do not replace browser playback tests.
9. Validate `/lectures`, `/lectures/<slug>`, and `/osa-cinema` in production in both languages.

## Rollback

If a source fails playback, remove its published URL from the catalogue and redeploy the last verified build. Do not mark the file as available solely because the URL has a valid shape. Retain text lessons and local progress; do not alter payments or entitlement logic as part of media rollback.

## Known limitations

Media catalogue URL validation cannot establish remote file existence, rights, accessibility, or duration. GitHub source inspection does not prove a production deployment. Current media sources remain null until verified recordings are supplied.
