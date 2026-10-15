# OSA Learning: seven-point release review — 2026-10-16

1. **Merge:** PR #68 merged to `master` as `9afadeef56ca1a41405fa014b7302f9bca548cf7`.
2. **Pre-merge CI:** five GitHub Actions workflows reported success for PR head `011b08b86a0a60ffb5aa155c21f6ed0f5d6a6dc9`. This is not a claim about later commits.
3. **Master CI coverage:** OSA quality workflow updated to run on relevant `master` pushes; previously push trigger only targeted the audit branch.
4. **Routing:** source `src/main.tsx` contains OSA routes. Live `/lectures` and `/osa-cinema` requests could not be independently verified from the available web client. Production route verification remains open.
5. **Media:** the catalog still has `src: null` for pending audio/video. Neither remote file availability nor rights clearance is confirmed; do not advertise recordings as published.
6. **Security and tests:** media URL validation and smoke tests were strengthened. New changes must pass CI before being treated as release-ready.
7. **Deployment:** `.github/workflows/cloudflare-pages.yml` runs a build/check on `master` pushes but the deploy step has `if: github.event_name == 'workflow_dispatch'`. A successful push workflow is **not** evidence of a production Pages deployment. Production deploy requires an explicit workflow dispatch with `target=production`, valid Cloudflare secrets and a confirmed deployed URL. No such dispatch is claimed here.

## Release acceptance criteria

- Green CI on latest `master` SHA.
- Explicit Cloudflare production deploy run and success.
- Independent HTTP and browser validation for `/`, `/lectures`, `/lectures/intelligence-and-imitation`, `/osa-cinema` (both locale variants where applicable).
- Media playback tests only for approved, actually hosted files.
- No false claims of active subscriptions, paywalls, certifications or released recordings.
