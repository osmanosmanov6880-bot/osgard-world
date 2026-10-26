# OSA CINEMA V44 / real published spectator acceptance

Problem: PR browser tests and Cloudflare builds cannot prove that the latest audience interface reached public HTTPS. V44 provides read-only live acceptance, not film release.

- A nonvisual data-cinema-release=v44 marker identifies the actual React viewer generation.
- On PR: check source integrity, mobile controls, original portal WebP, V20 NO-GO and TypeScript.
- On successful OSGARD frontend deploy from master (or an explicit master workflow dispatch): check production HTTPS from real Chrome/Chromium, 390px mobile and 1536px desktop, 8 chapters, RU/EN, deep-link reload, no horizontal clipping, bundled WebP and absence of private film/payments.
- Upload browser evidence without exposing private owner materials.
- If production is stale or unavailable, the live verification fails and no claim of publication is made.

A successful test certifies the interface observed at that moment, not commercial film rights. Rights, media, payment and premiere remain NO-GO.
- V44.1 hardens this check: the production SSH archive stamps the exact `GITHUB_SHA` in both the root and cinema HTML shells; the browser must read the same SHA supplied by the completed master deployment run. A stale page or different deployment cannot pass solely because it shows the generic V44 marker.
- The live test now selects each of the eight chapters, checks last-scene bounds, opens the genuine full-screen interactive dialog, closes it with Escape, and confirms keyboard focus returns to its launch button.
- This SHA stamp is an ordinary build/deployment receipt, **not** cryptographic proof of licensing, rights or CDN integrity. No video, payments or release authorizations were changed.
