# OSA CINEMA V44 / real published spectator acceptance

Problem: PR browser tests and Cloudflare builds cannot prove that the latest audience interface reached public HTTPS. V44 provides read-only live acceptance, not film release.

- A nonvisual data-cinema-release=v44 marker identifies the actual React viewer generation.
- On PR: check source integrity, mobile controls, original portal WebP, V20 NO-GO and TypeScript.
- On successful OSGARD frontend deploy from master (or an explicit master workflow dispatch): check production HTTPS from real Chrome/Chromium, 390px mobile and 1536px desktop, 8 chapters, RU/EN, deep-link reload, no horizontal clipping, bundled WebP and absence of private film/payments.
- Upload browser evidence without exposing private owner materials.
- If production is stale or unavailable, the live verification fails and no claim of publication is made.

A successful test certifies the interface observed at that moment, not commercial film rights. Rights, media, payment and premiere remain NO-GO.
