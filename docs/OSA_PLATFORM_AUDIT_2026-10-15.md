# OSA Learning / OSA Cinema — platform audit

**Audit date:** 2026-10-15  
**Scope:** GitHub source review, route/component inspection, media-manifest comparison against the authenticated Runway recent-assets list, and recent OSGARD deployment workflow results. This is a source audit, not a claim that every browser scenario was manually exercised.

## 1. Project map

| Surface | Repository / runtime | Confirmed role |
|---|---|---|
| OSGARD WORLD | `osgard-world`, React 19 + Vite 6 + TypeScript, static Nginx/Docker | Existing public portal and product ecosystem |
| Main route `/` | `src/main.tsx` routes to `OSAIntelligenceHome` | OSA Intelligence landing page |
| `/portal` | `src/App.tsx` via route dispatcher | Broader ecosystem portal |
| `/academy` | `src/AcademyHome.tsx`, `src/AcademyStudio.tsx` | Learning routes, practical prompt lab, local progress and self-check |
| `/osa-cinema` | `src/OSACinema.tsx` | Three-act interactive story with choices, insights, sources, restart, and local progress |
| `/lectures` | `src/LectureLibrary.tsx` | Ordered scene catalogue and honest video-publication notice |
| `/osa-library/` | `public/osa-library/index.html` | Course map, 31-row media inventory, recovery status |
| Canonical OSA source | `osa-global-intelligence`, Next.js 14 | A separate OSA app: `/` redirects to `/cinema`; contains Interactive Cinema, Decision Lab, AI Field Guide, documentation, and the media manifest |

## 2. What works in source

- Interactive scenes, user choices, contextual explanations, course completion and self-check.
- Russian and English UI in the principal Academy/Cinema components.
- Local progress storage with guarded reads/writes in the checked components.
- Course catalogue links to actual interactive scenes.
- Responsive Academy CSS and reduced-motion styling exist.
- OSGARD release workflow includes TypeScript checks, build, Academy/lecture smoke tests, an OSA portfolio-case check, and production route verification.
- Current deployed frontend commit: `c10b9d0bc4cb05c0a63560fad3ccbf6dd0de8d2b`; deploy workflow: https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/38679658792.

## 3. What is not implemented or is not yet proven

- The checked Cinema and Lecture Library components do not render real HTML `<video>` or `<audio>` players.
- Browser-local progress is not user-account progress, is not synchronized across devices, and the two app variants use different localStorage keys.
- No confirmed server-side learner authentication or permissions were found in the inspected routes.
- No Stripe/checkout dependency or payment API routes were found in the inspected package/manifests. `OSA_SUPABASE_URL` and a service-role key exist only as empty example environment variables; that is not proof of a Supabase integration.
- There is no confirmed course purchase history, recurring subscription management, certificate issuance, or cross-device learning analytics.
- Existing “skill map”/self-check is explicitly not an official certificate.
- The separate Next.js app is currently marked `noindex`/nofollow in metadata. Do not change search visibility without a deliberate launch decision.

## 4. Media audit after Runway connection

Canonical manifest: 31 records — 19 video, 9 audio, 3 images. All `permanentUrl` values are null.

The authenticated Runway recent-assets list returned 31 recent assets. Exact IDs match 28 manifest entries: 18 videos, 7 audio assets, 3 images. Three manifest IDs did not appear by exact ID in the recent list:

- Video: `a0d3d701-8893-40a5-a064-71c934e73a8d`
- Trailer voiceover: `db58afba-0d6d-4ca4-946d-90eb1a7791da`
- Alternate trailer voiceover: `b85171e3-8d86-47de-b65a-7f955a25dd9a`

Not appearing in the recent list does not prove deletion. Some audio is similarly named but has a different asset ID; do not automatically substitute it.

The available names/briefs indicate cinematic visual inserts and short introductory/trailer/music assets, not a complete sequence of explanatory lecture videos and narrated lesson tracks. No temporary signed URL is being stored in source code. The media are not yet published as durable files, so playback remains blocked.

## 5. Monetization recommendation

Start with a free introductory interactive course. Once one complete lesson pack has proven value, test a **one-time purchase** for a defined mini-course rather than launching subscriptions immediately. Subscription depends on recurring high-quality releases and creates refund/support expectations before the library is ready.

Illustrative hypotheses to test, not market facts:
- €9–19: concise starter course;
- €29–59: a full, practice-led course with audio/video, transcripts, exercises, and assessment;
- team pricing only after a repeatable business/education offer exists.

Before integrating real payments, confirm seller jurisdiction and eligible provider. Keep card data with the provider; validate signed webhooks server-side; add idempotency, order/payment/subscription/access state separation, refunds and cancellation flows. Do not simulate entitlements in localStorage.

## 6. Prioritized implementation plan and files to touch

### Stage 1 — media foundation (blocked until durable hosting is configured)

1. Resolve or explicitly replace the three IDs not matched in the recent Runway list.
2. Export and host approved source files on permanent HTTPS storage with byte-range support.
3. Extend `osa-global-intelligence/public/interactive-cinema/media-manifest.json` with title, role/chapter, locale, duration, captions/transcript, rights, checksum, and publication status.
4. Add a reusable accessible player to `osgard-world/src/OSACinema.tsx` / `src/LectureLibrary.tsx` and the canonical Next.js `components/InteractiveCinema.tsx` only where required. Preserve the current interactive scene if a media file is absent.
5. Add player tests for error state, missing URL, keyboard, mobile, playback-resume and captions.

### Stage 2 — unified learning catalogue

- Start with `src/LectureLibrary.tsx`, `src/OSACinema.tsx`, and `src/AcademyHome.tsx`.
- Add a small shared lesson data module and typed metadata instead of duplicating descriptions.
- Structure course → module → lesson → practice/check → final task. Only mark material as audio/video when the permanent, playable file is verified.

### Stage 3 — accounts and persistence

- Choose the actual backend/identity provider before implementing. Do not add a second database solely for the appearance of an account feature.
- Migrate from local-only progress to server-synced progress only after authenticated user identity, authorization, privacy and backup are in place.

### Stage 4 — paid access

- Add server-side order/access model, payment provider, signed webhooks and refund/cancellation handling only after seller jurisdiction, credentials and test mode are confirmed.
- First validate a one-time course sale. Introduce subscription only if recurring content supports it.

### Stage 5 — release quality

- Run existing `npm run check`, `npm run build`, `npm run qa:academy`, `npm run qa:lectures`, and production route tests.
- Add media playback, keyboard/screen-reader and narrow-mobile checks; document exact output and deployment SHA.
- Keep production payments disabled until end-to-end test-mode flows pass.

## 7. Small, safe changes in this branch

- Updated the media CSV to distinguish exact IDs found in Runway from IDs not found in the recent-assets response; permanent URLs remain blank.
- Updated the recovery runbook and canonical source-of-truth status after confirming the connection.
- Updated public media-library status copy. No app route, homepage, database, payment, or player code is changed in this audit branch.
