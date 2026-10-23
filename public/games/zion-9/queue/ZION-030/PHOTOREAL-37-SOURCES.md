# ZION-030 v37 — Photographic material provenance and limitations

## Verified asset sources

The playable Three.js city progressively requests six `1k` JPG material channels from Poly Haven. These are photographic assets supplied under **CC0**; attribution is appreciated but not legally required for the assets.

| Family | Asset | Channels streamed |
| --- | --- | --- |
| Road asphalt | [Asphalt 03](https://polyhaven.com/a/asphalt_03) | Diffuse and OpenGL normal |
| Architectural stone | [Sandstone Blocks 04](https://polyhaven.com/a/sandstone_blocks_04) | Diffuse and OpenGL normal |
| Worn plaster | [Plastered Wall 05](https://polyhaven.com/a/plastered_wall_05) | Diffuse and OpenGL normal |

License: https://polyhaven.com/license

All remote texture URLs are static asset file URLs under `dl.polyhaven.org`. The game does **not** use Poly Haven's live metadata API. No API keys or user data are sent to Poly Haven by the game. The browser may fetch image files directly from their CDN on supported desktop configurations; normal requests convey ordinary web request headers.

## Fail-safe behaviour

- If a source URL fails or the browser is offline, the city retains a **fully authored deterministic procedural albedo/normal/roughness set**. It is not silently replaced with black or untextured geometry.
- The authentic photo maps are optional asynchronous visual upgrades, **not included within the production archive**. Their availability is reported as `photoreal.photoTexturesLoaded` and `photoTextureErrors`; do not describe the production build as containing those original JPGs.
- Hardware benchmark reports both materials and GPU identification. `OSGARD_REQUIRE_PHOTO_PBR=1` can fail a strict GPU capture unless at least four photo channels actually loaded.
- Texture quality is 768px per procedural map on accelerated desktop (three families, nine maps), 256px on mobile; software/reduced-motion paths avoid photo downloads and texture synthesis. Real photo maps request 1K.
- PMREM sky reflections are **procedurally constructed**, not an HDRI photograph or traced global illumination.
- Cinematic clearcoat, shadows and grading are rasterized Three.js features. This is not path tracing, Unreal Nanite, Lumen, MetaHuman, full-scene photogrammetry or AAA-grade photorealism proof.

## Production recommendation

To make the release reproducibly photorealistic offline, pin and self-host optimized, licensed PBR textures (preferably KTX2 with mipmaps and LOD). Validate CORS if continuing to use third-party delivery, verify real mobile/desktop screenshots, and run the provided GPU matrix on actual hardware before merging and deploying.
