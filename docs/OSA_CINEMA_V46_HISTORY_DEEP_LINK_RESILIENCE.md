# OSA CINEMA V46 — Reliable Browser History and Deep Links

**Source baseline:** V45 production accepted as `58861c02e270a88b790ae0eb78962c98bd78e4cf`.

## New visitor behavior
- Deliberate navigation between eight story chapters now pushes an actual same-document history entry. Supported surfaces: mobile chapter select, desktop chapter list, act rail, companion, archive, full-screen Next/Previous, regular story controls, and keyboard arrows.
- Browser Back and Forward restore the exact chapter and RU/EN language. During full-screen screening, scene progress also follows browser history without closing the dialog.
- Initial hydration, reload, and URL canonicalisation use replaceState instead of adding spurious history entries. Progress and choices remain stored locally.
- Ambiguous, negative, duplicate, out-of-range and noncanonical chapter/language parameters are rejected safely and normalised. Unrelated search parameters and anchor hashes are retained.
- The active chapter heading announces updates politely to assistive technology. Existing `data-cinema-release='v44'` remains intact for compatibility with verified V44/V45 checks; `data-cinema-navigation='v46'` identifies this navigation feature.

## Review evidence requirements
1. One exact-head pull request with all required CI successful: TypeScript, shared ecosystem browser suite, OSA V13, V44/V45 source-contract and V46's **five actual parser and release tests**.
2. The two additional V46 Playwright test scenarios must execute in both desktop and mobile projects before merging (4 executions), verifying Back/Forward, language, full-screen state, reload, malformed links and permanent NO-GO.
3. No merge with conflict, old SHA or pending/failing check. The approved OBSIDIAN ARCHIVE design, eight original scenes and four reference WebPs cannot be changed.
4. After merge, require new exact master SSH deploy SUCCESS with freshness checks, checksums, rollback activation and live OSA smoke.
5. Only after the deployed SHA is confirmed, run the independent real HTTPS Chromium suite: **12 executions total (V44 6 + V45 2 + V46 4)**, source receipt matching, and saved authentic evidence artifacts. Cloudflare build or skipped post-deploy job is never a release PASS.

## Commercial and media restrictions
This remains an interactive educational still-image experience. No film production, recorded AV distribution, streaming rights, subscription checkout, ownership claims or paid payments are unlocked by V46. The V20 rights/publication/checkout policy is permanently NO-GO pending separate verification and authorization.
