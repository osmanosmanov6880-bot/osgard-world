# OSA Learning — evidence-based audit (2026-10-16)

## Scope and safety
Read-only inspection of GitHub default branches. No deployment, production database change, payment activation or asset publication has been performed. This report records verified source observations, not successful runtime tests.

## Repository topology
- osgard-world: Vite 6, React 19, TypeScript; main production frontend; branch master.
- osa-global-intelligence: Next.js 14, React 18; separate interactive cinema and research project; branch main.
- osa-global-intelligence-2: Next.js 14, React 18; staged transfer project; branch main.
Do not merge Next.js components directly into the Vite application without adapting imports, routing, styles and dependencies.

## Main routes (src/main.tsx)
- / -> OSAIntelligenceHome, except query project or hash #project-studio -> AcademyHome.
- /portal -> App (OSGARD portal).
- /academy -> AcademyHome.
- /lectures -> LectureLibrary.
- /lectures/:slug -> OSALessonPage.
- /osa-cinema -> OSACinema.
This is source-level evidence, not verification of currently deployed nginx routes.
Duplicated /archive condition is present and can be cleaned up in a dedicated change.

## Verified lesson content
src/osaLessonGuides.ts defines eight canonical lesson slugs:
1. intelligence-and-imitation
2. how-language-models-work
3. power-of-knowledge
4. signal-and-noise
5. verify-an-ai-answer
6. privacy-before-prompting
7. human-in-the-loop
8. investigate-the-future

Guides provide objectives, examples, glossary, quiz with explanation, exercise and source metadata in ru/en. Editorial verification of all external URLs and completeness of long-form lesson texts remains open.

## Media status
src/osaMediaCatalog.ts constructs audio/video entries for each canonical lesson and both languages, all with src: null by default. No media file is playable through this registry until a durable asset URL is supplied. Do not interpret an asset manifest or a scene as a recorded MP4/MP3.
src/OSAMediaPlayer.tsx includes seek, playback speeds 0.75x–2x, volume, position persistence in localStorage, caption tracks and error handling. This is code inspection, not a browser test.
scripts/osa-media-player-smoke.mjs uses assertions and source text inspection; the existence of a test does not mean it was executed or passed.

## Learning progress
LectureLibrary reads getOSALearningProgress() and subscribes to changes. Local browser persistence is not cross-device sync and cannot be used as proof of server-side identity.

## Important open questions
1. Enumerate physical audio/video files in the deployed public asset directory and compare with media registry.
2. Review full lesson detail and source references for correctness.
3. Inspect authentication, backend, payment and entitlement paths before promising paid access.
4. Check Docker/nginx and live routing; source routes are not production deployment proof.
5. Run npm ci, npm run check, npm run build, qa:academy, qa:lectures, qa:osa-media, qa:osa-progress, qa:osa-narration, qa:osa-media-files and inspect actual exit codes.
6. Browser-test desktop/mobile, keyboard accessibility and player behavior using real sample media.
7. Inspect the separate OSA repositories' transfer manifests for genuinely reusable materials.

## Proposed implementation order and initial file impact
Phase 1: read-only asset inventory and quality gate scripts; scripts/osa-media-file-audit.mjs, scripts/osa-narration-readiness.mjs, src/osaMediaCatalog.ts.
Phase 2: reconcile canonical lesson records; src/osaLessonGuides.ts, src/LectureLibrary.tsx, src/OSALessonPage.tsx.
Phase 3: real media publication; src/osaMediaCatalog.ts and public/osa-media assets, src/OSAMediaPlayer.tsx only for confirmed defects.
Phase 4: design server-side user accounts and entitlement checks after backend discovery. Never store trusted payment status in localStorage.
Phase 5: route/navigation integration and deployment, with rollback plan.

## Launch monetization hypothesis
Free introductory lessons plus one-off purchases of finished courses. Proposed price tests: RUB 990–2990/course, not validated demand. Subscriptions only after recurring premium content exists. No real checkout until provider, legal geography, backend signature verification, webhook idempotency, refunds and entitlement enforcement are tested.

## Release gates
- Actual lesson text and source URLs reviewed.
- Media file exists, URL resolves, codec and content type checked, player works.
- No fake media buttons.
- Accessibility and mobile checks.
- Build and smoke tests pass in CI.
- Backup, staging smoke test, rollback documented.
- Paid content requires authenticated server-side authorization.

## Files examined
package.json, index.html, src/main.tsx, src/App.tsx, src/osaMediaCatalog.ts, src/osaLessonGuides.ts, src/OSAMediaPlayer.tsx, src/LectureLibrary.tsx, scripts/osa-media-player-smoke.mjs; package.json and README.md of the two OSA repositories.
