# OSA narration production plan

Updated 2026-10-15

## Source and scope

Narration scripts are derived from the existing bilingual structured lesson sources:

- src/osaLessonReading.ts: the three reading sections and key takeaways.
- src/osaLessonGuides.ts: objectives, practical example, glossary, exercise steps and success criteria.
- The interactive knowledge check and raw source URLs are intentionally not spoken; the learner can use them on the lesson page.

scripts/osa-narration-readiness.mjs builds and validates one script for each of the eight lesson slugs in Russian and English (16 planned scripts). It splits narration into segments no longer than 4,500 characters to stay below a 5,000-character TTS input cap. The script hashes each segment and estimates credits at one credit per 50 characters, rounded up separately for each segment. It performs no external generation calls and never deducts credits.

## Voice decision

Do not batch-generate all sixteen tracks before auditioning one short sample. A voice must sound natural in Russian and English, pronounce abbreviations and technical terms correctly, and maintain a calm, intelligible pace. The connected Runway workspace returned no suitable voice through the free Russian voice search, and no TTS generation was started during this pass.

Recommended production order when credits and a voice are available:
1. Choose one voice using an auditioned 30–60 second excerpt from "How language models work".
2. Review Russian pronunciation and pacing with a human listener; do not accept a synthetic sample as quality-approved merely because it generated successfully.
3. Generate the Russian pilot in 4,500-character segments, join without dropping pauses, inspect loudness/peaks, and measure the final duration.
4. Save transcript and timed subtitles; check every segment boundary and test playback on desktop and mobile.
5. Only after the pilot passes, generate the remaining Russian tracks. Generate English tracks after the RU voice/process is accepted or a separate EN voice passes audition.
6. Store binaries at durable same-origin /osa-library/media/ paths or approved project-controlled HTTPS storage, then populate the runtime media catalogue. Never use Runway signed gallery URLs as final sources.

## Cost and release gates

Run npm run qa:osa-narration to get a deterministic count of characters, segments, and estimated TTS credits per lesson and locale. Estimates are not billing guarantees; the actual provider model, segment sizes, selected voice and pricing must be rechecked before any paid generation.

The narration readiness check requires eight valid lessons in each locale, three source reading sections and key takeaways per lesson, objectives, examples, glossary, practical exercise, source metadata and successful segmentation. It does not mark audio as generated, publish media URLs or open the media release gate.

Launch only after each selected audio file has a durable URL, measured duration, language, transcript/subtitle metadata where appropriate, rights status, human QC and browser playback verification.
