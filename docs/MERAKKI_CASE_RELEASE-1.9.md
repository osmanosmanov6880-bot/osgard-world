# MERAKKI GLOBAL Case — release 1.9

## Project brief actions
- Added a local UTF-8 `.txt` export with a fixed filename and object-URL cleanup.
- Added native Web Share API support when the visitor explicitly clicks Share. Unsupported browsers and cancelled/failed share attempts have localized feedback.
- Added the new controls in RU, EN and AR/RTL, with responsive button layout.

## Privacy boundary
- Form input remains in the current page. Download creates a local text file; no endpoint, background request or persistence was added.
- Native sharing is invoked only from the button click and is user-controlled. The interface does not claim that a message reached its recipient.
- The restaurant storefront remains demo-only. Real order submission and payment processing are not enabled.

## Verification
- `npm run qa:merakki-case` exercises the inline page logic with a lightweight DOM harness, including generated brief, clipboard, local download, native share, cancellation and unsupported-browser cases.
- The ecosystem integrity smoke and production route matrix require the copy/download/share controls on RU, EN and AR routes.
- Publication must be confirmed by the matching GitHub Actions validation and SSH deployment run; this file alone is not evidence of public availability.
