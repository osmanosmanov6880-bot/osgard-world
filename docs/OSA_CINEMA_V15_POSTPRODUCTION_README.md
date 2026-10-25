# OSA CINEMA V15 — Montage & Source Clearance

**Status:** editorial candidate plan only. This work does not publish or pretend to have finished film masters.

## What exists

- The canonical inventory lists 31 historical Runway asset references in `public/osa-library/media-inventory.csv`; the source IDs are not permanent URLs.
- The V15 edit decision list maps **19 candidate video shot placements** across the eight published interactive chapters, with alternate reuse explicitly marked.
- Four existing audio source IDs have been shortlisted for audition and mixing; some Runway audio assets are classified as `image` by the upstream gallery, so **verify the actual file signature** rather than trusting the gallery label.
- Rights approval, duration, in/out points, final masters, subtitle timing and quality checks intentionally remain null/false.

## Editorial production gates

1. **Export and preserve originals** from the connected Runway workspace under a controlled production directory. Signed `?_jwt=` source links must never be checked into GitHub or copied to the public media catalogue.
2. **Inspect the actual bytes**, not names: run `ffprobe -v error -show_format -show_streams exported.mp4`; check codec, resolution, duration, frame rate, colour and audio. For voice/music, inspect the MP3 container and loudness.
3. **Establish rights provenance** and attribution conditions for every original video, score, voice and graphic. Keep a source ID, its Runway task reference, responsible reviewer, SHA-256 and permission in the release log.
4. **Build the rough cut** using `osa-cinema-v15-edit-decision-list.json`: assign measured in/out points, use editorial shot candidate order as a proposed sequence, and overlay only properly verified statements. Do not portray synthetic historical scenes as real archival footage.
5. **Record/approve both languages**: Russian and English narration are distinct deliverables. Match scripts to the eight `OSA_LESSON_SLUGS` and create accurate WebVTT subtitles, including timing and language-specific review.
6. **Export video masters** as browser-tested MP4/H.264 and optional WebM. Store the mastered media in long-lived same-origin storage or an approved permanent HTTPS media host.
7. **Run media release preflight**, existing file signature checks, playback tests, and the separate V13/V14 public browser acceptance before wiring media into `src/osaMediaCatalog.ts`.
8. **Only then** flip `finalIncluded`, `rightsApproved`, `visualQC`, `masterVideo` and publication fields in a reviewed PR. A premium-looking UI is not proof that an unapproved video exists.

## Source selection (candidate, not final)

| Scene | Narrative use | Proposed Runway source inventory slugs |
|---|---|---|
| 1 | Intelligence or imitation? | macro-eye-reflection; city-aerial-opening; desk-ai-encounter |
| 2 | How language models work | research-table-overhead; archival-reading-room |
| 3 | The power of knowledge | historical-library; global-city-night; historical-reenactment |
| 4 | Signal and noise | macro-eye-alt; research-table-overhead |
| 5 | Verify the answer | archival-reading-room; designer-engineer-work |
| 6 | Privacy before prompting | desk-ai-encounter; observatory-reflection |
| 7 | Human in the loop | designer-engineer-work; desk-before-sunrise |
| 8 | Investigate the future | human-horizon; desk-before-sunrise; modern-city-wide |

## Useful local acceptance commands

```bash
node scripts/osa-cinema-v15-edit-decision-smoke.mjs
npm run qa:osa-media
npm run qa:osa-media-availability
npm run qa:osa-media-files
npm run qa:osa-media-release
```

The first command must pass on the **blocked draft**. The media release checks currently gate publication; they are not evidence that film content has shipped.

**Separate site:** `osa-cinema-beyond-the-model.osman-absolu-5357.chatgpt.site` is independent from the OSGARD GitHub deploy. Edit the site's own project to update V12, or clearly designate that URL as an archive when appropriate.
