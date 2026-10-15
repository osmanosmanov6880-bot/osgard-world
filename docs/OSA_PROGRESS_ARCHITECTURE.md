# OSA unified learner progress

Updated: 2026-10-15

## What changed

OSA lesson completion and OSA Original cinema state now pass through the unified versioned persistence boundary in src/osaProgress.ts, shared by the Academy overview, searchable lecture library, individual lesson pages, and OSA Original interactive cinema.

The canonical local snapshot is stored under osgard-osa-learning-progress-v1. It contains validated lesson completion slugs, the last opened detailed lesson, the cinema scene and answers, the language, completion flag, the three self-checks, and an update timestamp.

## Backwards compatibility

On first read, the store migrates the previous keys without deleting them:

- osgard-osa-lesson-completion-v1
- osgard-osa-cinema-progress-v1

The migration deduplicates valid lesson slugs, rejects unknown identifiers, clamps invalid scene indexes, removes choices on scenes that have no choices, validates answer ranges and retains only the three supported self-checks.

## Behaviour and limits

- Updates dispatch one shared same-tab event; other tabs refresh from the browser storage event.
- Invalid or corrupted records are normalised rather than crashing the learning UI.
- If browser persistence is blocked, the current tab falls back to an in-memory snapshot and the lesson page reports that the change was not persisted.
- The lecture library offers a continuation link for the last detailed lesson opened.
- Course restarts reset cinema state but preserve lesson completion history and the last detailed lesson.

This is still browser-local progress. It does not create accounts, synchronize devices, issue certificates, or grant paid access. localStorage must never become an authority for purchases, subscriptions, roles, or certificates. A future authenticated API adapter must verify user identity and ownership on the server before any cross-device or entitlement feature is enabled.

## Verification

npm run qa:osa-progress exercises legacy migration, malformed data, rejected slugs, valid and invalid scene answers, storage errors, change events, and preservation of independent learning records. It runs in frontend validation, the main VPS deployment workflow, and the static Cloudflare Pages build.
