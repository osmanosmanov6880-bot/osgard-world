# OSGARD — Five-Wave Unified Release Candidate

**Repository:** `osmanosmanov6880-bot/osgard-world`  
**Draft PR:** [#182](https://github.com/osmanosmanov6880-bot/osgard-world/pull/182)  
**Source baseline:** `master` at `731c00385af77428130857886c5c60df0cbaed2b`, plus audited commits from #174–#179.  
**Deployment status:** NOT DEPLOYED. Do not merge or publish until the full CI and release gates pass.

## WAVE 1 — Preserve and integrate all six working surfaces

- **Play:** 19 existing game worlds, cinematic transitions, responsive catalog, search, genre/availability, favorites and game details (#174).
- **World:** a photographic satellite Earth fallback, true 3D controls, three entryways, responsive Cosmic Portal (#175).
- **Academy:** verified local learning progress, practice and eight lessons, bilingual student experience, accessible JSON backup (#176).
- **Intelligence:** interactive evidence-selection lesson, explicit teaching-only disclosure, primary NIST references (#177).
- **Development:** true public case imagery/links, status labels grounded in catalog metadata; working brief download and contact link (#178).
- **Entertainment:** illustrated seven-game archive with RU/EN/AR content and direct link to the complete Play catalog (#179).
- Preserve **Time Omega v0.21 preview** from current master and Play's defensive gameplay telemetry. Components and tests altered by multiple PRs are reconciled **manually**, never replaced blindly.
- Retain existing protected routes, server behavior, legacy game files and authenticated flows.

## WAVE 2 — One understandable ecosystem

- New **OSGARD Ecosystem Index** on World: six real destinations, not mock apps.
- Category filters (All / Learn / Play / Build), Russian-language search, readable destination cards and accessible controls.
- The existing first-screen World, three main portals, cinematic NASA globe and full Development layout remain intact.
- Mobile uses single-column cards and touch targets. Reduced-motion and keyboard focus are preserved.

## WAVE 3 — Real self-service without registration

- Search and filters respond immediately without calls to a server.
- `osgard:recent-destination:v1` stores **only** an approved destination id locally, never message text or identifying data.
- “Continue” returns to the last opened section; history can be cleared in one click.
- Unavailable/blocked browser storage is caught; navigation must remain functional without storage.
- No fictional real-time status, certificates, AI verification, payments or live multiplayer is claimed.

## WAVE 4 — Regression protection, mobile and performance

- `scripts/unified-ecosystem-smoke.mjs`: validates route contracts, six source-backed destinations, required image assets, 7 archived games × 3 locales, 4 legacy cases × 3 locales, local consent disclosure, focus and reduced-motion requirements.
- `npm run qa:unified` can be called directly and is automatically included in existing `npm run qa:ecosystem` used by CI.
- `scripts/ecosystem-unified-index.spec.mjs`: Playwright on desktop and mobile tests search, tabs, keyboard, safe resume and clearing.
- Existing tests preserved and combined: World 3D/WebGL2/quality, Play catalog and strict mobile CLS, Academy localization, Intelligence/NIST sources, Development real cases, Entertainment RU/EN/AR.
- CSS for the new directory has a source-level limit of **16 KiB**; the browser lab retains its original CLS limit. These are code/test budgets, **not** a measured field Core Web Vitals claim.
- No redirects/forced migration of legacy game URLs; the archive is at `/entertainment/archive/` and the full catalog at `/entertainment/` or `/play`.

## WAVE 5 — Release gate and operational rollout

### Before review approval

- [ ] PR #182 points at the latest integration commit; no conflict with the current master.
- [ ] TypeScript, Vite, postbuild and all existing static QA success.
- [ ] New `qa:unified` gate success.
- [ ] Full Playwright desktop/mobile and OSA visual screenshots on **the same SHA** success.
- [ ] REMIX launcher safety, Cloudflare Pages build and release-readiness actions success.
- [ ] Check real screenshots for layout, contrast, hover/focus, text legibility and no mobile overflow.
- [ ] Verify source assets, case statuses, all 19 Play entries, old Academy progress and Time Omega v0.21.
- [ ] Review changed backend/deploy workflow effects and ensure there is no parallel deployment.

### Production deployment — a separate action requiring approval

1. Confirm the owner authorizes merging PR #182 into `master` and publishing. This PR does not do either automatically.
2. Confirm that the repository's `OSGARD frontend deploy` workflow is healthy, has backup/rollback, and that the server is not undergoing a concurrent release. A push to master also deploys **Core API/REMIX Guard**, not only static assets.
3. Merge the **exact reviewed SHA**, monitor GitHub Actions deployment to success and record release identifier/backup.
4. Post-deploy smoke: visit `/`, `/portal`, `/play`, `/intelligence`, `/academy`, `/development`, `/entertainment/archive/`, `/entertainment/en/`, `/entertainment/ar/`, `/games/time-omega-preview/` on desktop and phone.
5. Test the actual 3D fallback, Play filters/favorites/launch paths, NIST lesson, Academy resume/import, Development brief, local recent-history controls and API/auth compatibility.
6. Check CDN-cache integrity and correct asset content hashes. Do not imply protected Godot WebGL2, multiplayer or live account flows were verified if no suitable authorized environment was available.
7. On any failed health gate, use the existing deploy workflow's rollback and previously captured backup. Do **not** attempt manual SSH deployment concurrently with the workflow. Document the resulting state.

### Acceptance status

Until all checks above are supported by CI and post-deploy evidence: **REVIEW CANDIDATE ONLY**, not a completed production release.

Additional instructions for isolated Play rollback are documented in `docs/PLAY-CINEMATIC-DEPLOY.md`. This is an alternative to, not a simultaneous action with, the normal master deployment.
