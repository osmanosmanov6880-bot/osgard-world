# OSA CINEMA V45 — accessible screening and complete reference-art verification

V44.1 production was proven by source merge `433b4bf`, SSH deploy #40253076807 and live Chromium #40254642258. V45 hardens accessibility and image integrity. It is not a new film or visual redesign.

## Engineering scope
- When the full-screen dialog is open, the background siblings become `inert` to screen readers and keyboards. Their precise previous inert states are restored on dismissal, followed by previous scroll locking and keyboard focus.
- The existing dialog's Tab, Shift+Tab and Escape handling remains; if programmatic focus escapes, the next Tab returns it to the dialog.
- Production Playwright verifies all eight displayed scenes, decodes their four bundled reference WebPs, requires same-origin assets and nonempty alt text, checks scene progress and horizontal clipping, and tests keyboard isolation and restoration.
- V44's strict master-deploy SHA receipt, RU/EN, desktop/mobile and public film/checkout NO-GO checks are retained. V45 adds one browser scenario to each of the two existing Playwright projects: 8 executions total.
- The pre-deploy ecosystem V15 real-browser test now also checks the interactive modal's inert background, Shift+Tab focus trap and precise restoration on dismissal. This catches behavioral regressions **before merging**, not only after SSH production.
- New source contract validates all eight original scene-image mappings against the actual bundled WebP bytes and confirms every release guard remains present.

## Acceptance criteria
1. All applicable GitHub CI checks on the exact PR head must succeed; no force-merges or ignored browser failures.
2. Merge with `expected_head_sha` only when unchanged and conflict-free. Run new frontend SSH production deployment from the reviewed master commit.
3. After SSH SUCCESS, the existing read-only V44 workflow must execute V44 and V45 tests against real production HTTPS and upload original test evidence. A failed or skipped live job does not satisfy acceptance.
4. OBSIDIAN ARCHIVE art direction, existing eight scenes, and the V20 publication, rights and checkout NO-GO policy stay unchanged.

V45 changes only the interactive still-image experience. No recorded film, streaming, rights claims or payment controls are authorized.
