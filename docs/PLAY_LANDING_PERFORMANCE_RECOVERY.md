# OSGARD PLAY landing JavaScript performance fix

## Blocking production evidence

A prior SSH deploy run [#40016836652](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40016836652) failed at `npm run qa:redesign-build`.
It recorded `src/PlayHome.tsx: 97,851 / 97,280 gzip bytes` in the initial static dependency graph.

## Fix, without raising the 95 KiB budget

- Keep the hero and primary navigation in the initial PlayHome bundle.
- Move featured cards and the partner introduction to separate lazy modules.
- Keep game definitions, prices, availability, launch URLs, favorites and existing player data unchanged.
- Preserve server-side render availability through React Suspense.
- `scripts/play-landing-split-smoke.mjs` verifies the source boundary.
- `npm run qa:redesign-build` measures gzip bytes of the real Vite manifest graph, not estimated source size.

This change is a build-time performance correction for the PLAY catalogue; it does not touch Stripe, inventory or payments.

## Release criteria

The build budget must pass at 97,280 bytes or less. All SSR and browser route checks must remain green. A successful GitHub commit is not proof of publication; the SSH deployment still needs separate confirmation.
