# OSA Original — lecture library and media audit

**Audit date:** 2026-10-15  
**Public catalogue route:** `/lectures`  
**Interactive course route:** `/osa-cinema`

## What is available now

The Academy lecture catalogue reuses the existing OSA Original course data in `src/OSACinema.tsx`. It is organised in learning order and exposes every scene as a direct link:

1. **Act I — AI changes the rules**: the opening decision and how language models work.
2. **Act II — The power of knowledge**: information access, signal vs. noise, claim verification, and privacy.
3. **Act III — Human agency and the future**: applying AI with judgment and the final choice.

The current React course has eight scenes in each locale (Russian and English), choice feedback on relevant scenes, a progress bar, local progress persistence, and a completion self-check. The new `/lectures` page links to these real scenes; it does not duplicate the course engine or invent a second progress store.

## Video and audio audit

The source repository is `osmanosmanov6880-bot/osa-global-intelligence`, branch `main`. Its `public/interactive-cinema/media-manifest.json` reports:

- `hostingStatus: runway-gallery-assets-not-yet-permanently-hosted`;
- 31 listed media assets: 19 video, 9 audio, and 3 image records;
- **0 assets with a permanent URL** (`permanentUrl` is `null` for every record).

A recursive source-tree check found no committed `.mp4`, `.webm`, `.mov`, `.m3u8`, `.mp3`, or `.wav` media files. The source README and production-status document also explicitly distinguish interactive web storytelling from a rendered film.

**Conclusion:** the source repository does not currently provide playable, permanently hosted video lectures to copy. The assets are listed in a manifest but are not present as durable files. The catalogue therefore labels the current material as interactive lessons and states that video recordings are not published. It deliberately does not render fake video players or claim narration/audio is available.

## What is required to publish actual video lectures

1. Retrieve the originals from the authenticated Runway gallery using the existing asset IDs.
2. Review rights, content, and quality; export final video/audio files.
3. Put the approved media at durable HTTPS URLs (or commit appropriately sized files to a suitable media host).
4. Update the manifest with those permanent URLs.
5. Add a real video player with keyboard controls, captions/subtitles, transcript, poster image, and reduced-motion-safe behavior.
6. Test playback and caption timing on mobile and desktop before labelling a lecture “video available”.

## Validation

- `scripts/lecture-library-smoke.mjs` checks route registration, ordered scene links, sitemap, responsive styles, and the no-fake-video disclosure.
- `scripts/osa5-visual-smoke.mjs` includes the catalogue in desktop/tablet/mobile browser checks.
- A Git commit or green build alone is not evidence that the production deployment has completed; verify the deployment workflow and live route after merge.
