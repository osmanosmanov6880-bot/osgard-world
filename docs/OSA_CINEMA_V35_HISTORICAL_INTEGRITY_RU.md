# OSA CINEMA V35 - strict historical source provenance

This engineering module protects the three original GitHub editorial/rights-policy files:

- `docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json` (four source workprints)
- `docs/OSA_CINEMA_V18_PRIVATE_FOUR_TRACK_QA.json` (genuine four-track private audio QA metadata)
- `docs/OSA_CINEMA_V20_PRIVATE_RELEASE_POLICY.json` (unchanged NO-GO policy)

The protected baseline Git blob SHA-1 values were read from the owner's authenticated GitHub repository `osmanosmanov6880-bot/osgard-world` on 2026-10-25. The CI step calculates the Git blob digest from the actual checked-out bytes; independently it validates the required workprint IDs, four original audio tracks, matching V16/V20 source hashes, seven human decisions and all release/payment flags set to false.

Git blob SHA-1 pins detect unexpected byte differences but **do not prove the identity of a film rights holder** or replace a signed commercial license. A deliberate future change to the historical evidence needs a separate recorded legal/provenance review and independent confirmation, not a casual update of the three pins. Code review must not treat a test fixture as genuine media evidence.

V35 includes a separate pure unit-test entrypoint accepting synthetic test pins. In that mode the returned `verifiedHistoricalSnapshot` is deliberately `false` and `testOrCustomPinMode` is `true`. Only the production command with the source-embedded, pinned historical Git blobs can return `verifiedHistoricalSnapshot=true`. Neither mode can grant a premiere.

## Commands

```
node --test scripts/osa-cinema-v35-historical-guard.test.mjs
node scripts/osa-cinema-v35-historical-guard.mjs --root .
```

## Explicit limits

- No MP4, VTT, private signing keys, secrets, or legal agreements are added.
- No GitHub branch protection, human approval, identity verification, or rights review is replaced.
- The private V34.2 standalone archive contains an engineering V18 fixture. It MUST NOT be expected to pass this genuine-GitHub historical gate; this check must run in the real repository checkout, not on local synthetic archives.
- Existing V34.2 is not rewritten. The code-only V35 update is a separate reviewable addition.
- Public film release, streaming, subscriptions, and payment remain `NO-GO`.
