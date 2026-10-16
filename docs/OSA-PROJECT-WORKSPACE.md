# OSA practical project workspace

Route: `/learning/project`, linked from `/learning`.

A guest learner defines a goal, audience and plan, attaches an HTTP(S) evidence URL, writes a reflection and completes three self-review criteria. The readiness checklist reports field completeness only; it does not grade the work or validate the destination URL.

Storage is manual and local to the browser (`osa:project:v1`). JSON export/import supports moving a draft between devices. Imports validate schema, field lengths, file size, timestamps and evidence URL protocols before replacing the open draft. Imported data is allowlisted, and URL credentials are rejected. Importing does not overwrite saved work until Save is pressed.

Storage failures leave the draft available for export. Unsaved work triggers a navigation warning. A storage event blocks saving after another tab changes the saved version; Save also compares the current raw value against the loaded baseline. The user can export their draft and explicitly load the saved version. This is a browser best-effort conflict guard, not an atomic multi-client database transaction.

No accounts, cloud persistence, instructor grading, public portfolio publishing or payment entitlement are introduced by this change. The previously described SQL/cloud editor was not present in the retrieved branch or available local files and is not claimed as verified here.

Validation: `npm run qa:osa-project`, `npm run check`, `npm run qa:osa6-learning`, `npm run qa:osa-monetization`, `npm run qa:osa-progress`, `npm run build`.

Manual browser review remains required before merge: RU/EN, mobile width, editing/save/reload, JSON download/import, malformed import preserving draft, two-tab conflict, blocked storage, keyboard navigation and unsaved exit. Browser execution was unavailable in the implementation environment because no Chromium executable was installed.

## Local expansion
See `OSA-LOCAL-RELEASE.md` for the program, project collection, revision history, portfolio and experiment log added after the initial editor.
