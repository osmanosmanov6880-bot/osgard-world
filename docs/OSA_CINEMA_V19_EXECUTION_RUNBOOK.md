# OSA CINEMA V19 to public-film release: execution contract

**Verified engineering state:** V16 indexed 4 private RU/EN video workprints, V17 measured 10 private original sources and delivered a local editorial desk, V18 created a private four-audio-track 239-second review MP4 with objective cut points. Technical results do **not** grant distribution rights. Published OSA V15 is an eight-scene interactive learning experience, not this recorded film.

## V19 Block A: Intake actual subtitles and compare them with footage

- Use `tools/osa-cinema-v19-private-timeline.html` locally without network. Choose one of the four exact originals, open its MP4, verify its real SHA-256, jump between the measured 65/11 candidate shots, then import an actual local WebVTT written from the heard voice. The preview intentionally does not assert the speech's language.
- Use `scripts/osa-cinema-v19-caption-qc.mjs` to check duration, cue overlaps, malformed clocks, empty text, markup, reading speed, excessive line length and content hashes. A passing technical result is only a **caption candidate**.
- Preserve exported local timestamped observations in private storage and have an independent RU/EN reviewer listen to the real speech. Do not commit transcripts or private review exports into this public repository.

Example after placing your own verified MP4 and VTT in `osa-media-staging/`:

```bash
node scripts/osa-cinema-v19-caption-qc.mjs --root osa-media-staging --asset-id osa-v15-directors-ru --vtt captions/osa-ru.vtt --report local-private-reports/ru-caption-qc.json --strict-caption-qc
```

**Definition of done:** four actual language-matched captions, four source SHA matches, zero structural errors, and a human bilingual sign-off for each audible soundtrack. In the current committed V19 registry all are **PENDING**, because captions and hearing evidence were not supplied.

## Block B: Finish filmed picture, voice and sound

- Inspect every subjective edit (64 candidate cuts for each workprint, 10 for each trailer). Approve or request changes with shot-numbered feedback. Objective scene detectors do not approve a final cut.
- Bilingual native reviewers compare factual spoken RU/EN audio with the intended scripts, evaluate synthesis/performer consent, and confirm captions against the final audible track, not a draft guide.
- Sound engineer creates final masters preserving required clean stems and clear dialogue; perform true-peak/loudness, complete-decode, lip/sync and phone-speaker checks. Record a final hash of **each newly rendered actual master**, never relabel a workprint as final.

**Definition of done:** signed cut/mix/caption approvals and exact final-media SHA/stream reports stored privately; reject if a new mix invalidates subtitle timing.

## Block C: Rights chain and credits (hard block)

- Build a private per-asset rights ledger linking every video, image, sound recording, music track, voice, likeness, synthetic generation output, logo and third-party clip to a license document, parties, uses, territory, term, allowed ads/monetization and permitted derivative edits.
- Obtain the actual grants from rights holders and consent from necessary performers. Appoint a responsible human/legal reviewer; preserve originals and license evidence in restricted storage with an expiry/revocation process.
- Rights documents must not be included in a public source repository. Check licensing for both trailers and full film, including reuse in marketing creatives.

**Definition of done:** the human legal clearance dossier exists for each public media asset. No checkbox, hash, automated test or self-reported JSON can replace that clearance.

## Block D: Stable streaming infrastructure and frontend

- Publish only cleared final objects to durable, documented HTTPS storage; maintain source/object hash manifests, versioned filenames, correct video MIME, HTTP Range/206, CORS as necessary, restrictive security headers and reproducible rollback.
- Public player requirements: language selection for verified tracks, WebVTT captions and accessible controls, keyboard focus, touch targets >=44px, buffered playback, scrub, reconnect, reduced-motion handling, low bandwidth fallback, poster frames, and truthful narration/synthetic-content disclosure where applicable.
- Do not expose temporary signed render URLs, private source media, draft notes or unlicensed masters. Do not reuse the independent chatgpt.site V12 release as evidence of OSGARD deployment.

**Definition of done:** deploy staging media only after gates A-C. Independent Chrome desktop/390px mobile playback of actual streamed files, multiple browsers and degraded network scenarios must pass before public activation.

## Block E: Release and commercial operation

- Freeze and sign the final approved media hashes, written rights sign-off and the release tag; stage with no public indexation, test rollback and geographic delivery, then selectively enable recorded-film catalogue cards.
- Only after explicit rights coverage for paid exhibition: decide free trailer, paid long film/course bundle, price tests, refunds, customer support, VAT/tax and payment-provider reconciliation. Never sell unapproved media.
- Monitor play start, failure rate, completion, caption utilization, locale selection, customer support and consent/rights revocation. Assign incident on-call and maintain an instant takedown process.

## Launch decision

`docs/OSA_CINEMA_V19_RELEASE_GATES.json` is intentionally fail-closed: recorded film public release and paid availability remain `false`. V19 delivers **working offline tools + executable checks + a truthful acceptance ledger**, not actual unprovided captions, legal grants or public streaming. Merge V19 technical work only after the new quality gates pass; later publication requires separate human/legal authorization and real production acceptance.
