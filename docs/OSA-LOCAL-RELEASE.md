# OSA — local practical learning release

## Implemented
- `/learning/program`: complete practical pathway through the eight existing canonical lesson guides, with objectives, exercises, criteria, final project and review rubric.
- `/learning/project`: bilingual project editor, validation, manual guest save, draft export/import and best-effort cross-tab conflict detection.
- `/learning/workspace`: up to 20 projects, ten revisions per project, explicit restoration into the editor, backups, import validation and deletion confirmation.
- `/learning/portfolio`: locally selected projects that meet the five completeness criteria. No public hosting or instructor assessment is claimed.
- `/learning/experiments`: up to 100 observations comparing elapsed time and remaining errors with and without AI, including JSON transfer and cross-tab conflict protection. Negative time savings are shown as negative numbers.
- Existing learning progress, assessment history and pricing preview remain available.

All application data stays in browser localStorage. This is not cloud persistence. Browser data clearing removes it; JSON backups provide portability. Changing the host or port changes the browser origin and its storage. Use the same host and port when returning, or import your backup.

## Start
The delivery archive contains `PAGES/` (built site), `SOURCE/` (source) and `START.py`.
Extract the entire archive, then run `python START.py` (Windows: `py -3 START.py` or `START-WINDOWS.bat`). Python 3 is required for this convenience launcher. Open the URL printed by the server. Do not open `index.html` directly with file://.

For development: enter `SOURCE`, run `npm ci`, then `npm run dev -- --host 127.0.0.1`.
This is a local preview build, not a release approved for production. The repository-wide Cloudflare preflight fails because the existing Godot game export `games/null-shift-godot/index.html` is absent. OSA source and build checks pass; the complete site requires its game export before that release gate can pass. Publishing is not performed by this release.

## Validation
Pure data tests cover project import validation, URL restrictions, revision history bounds, collection limits, duplicate IDs, portfolio eligibility, experiment numeric validation and negative deltas. TypeScript, production build and existing learning/media checks are run separately. HTTP route checks confirm the local delivery server serves deep links and rejects missing assets normally; these do not replace browser interaction tests.

Browser interaction and visual review remain pending. The available environment has no Chromium executable, and the attempted browser download returned an invalid archive.

## Remaining master-plan work
- Server accounts and cross-device persistence with real user authorization and database isolation.
- Instructor assignment, grading and authentic skill credentials.
- Real course audio/video production and accessibility QA.
- AI Tutor with course citations and evaluation; no API calls or model responses are simulated here.
- Orders, payment provider, signed webhooks, refunds and server entitlements; checkout remains unavailable.
- Corporate administration, production monitoring, pilots and outcome/economic measurements.

These require infrastructure access, actual teaching/media content, external integrations or pilot participants. A local static release is not represented as completing those stages. GitHub and production are untouched in this turn.
