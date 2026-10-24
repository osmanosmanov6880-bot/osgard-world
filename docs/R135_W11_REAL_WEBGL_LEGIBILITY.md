# R135 W11 — actual WebGL scene legibility gate

## Why W10 is not yet production ready

Software-native gameplay checks passed on master in run `40115027195`, but a separate **visual audit of the actual artifact** found that optical inspection in a 1082×2202 portrait screenshot was almost entirely black.

Baseline, using consistent pixel region x=20–82%, y=32–66%:
- W10 optical portrait: median luma **10/255**, 100% of pixels below 40.
- W10 desktop: median luma **26/255**, 58.1% below 40.
- This is a reproducible contrast/visibility defect; no FPS or physical hardware conclusions are inferred.

Verified W10 artifact: GitHub run `40115027195`, file `12568111714`; source `0ba0256f663609fe73ef9c54d953227d8d86f273`; manifest SHA-256 `18ed111b25c70ec34b4aa78ecbcb5d989786a449e7fdeb3e848e1af5f3e4d6f0`.

## Implemented W11 changes

1. One camera-targeted, shadow-free `OmniLight3D` inspection fill to light metal-heavy GLBs in ECO. Shadow-free and bounded light range limit avoidable mobile rendering cost.
2. Restrained brighter neutral world ambience/key and studio materials, rather than uncontrolled neon.
3. Active optical fault `Label3D` with disabled depth test, larger dark outline and meaningful amber/green text so mechanical beams cannot hide the lesson instruction. **No simulation logic changes.**
4. Read-only QA telemetry for fill-light energy, radius and shadow policy, plus caption visibility behind opaque geometry.
5. Added repeatable screenshot luminance test `scripts/r135-w11-readability-qa.py`. It requires optical portrait median >=28, dark fraction <=82%; desktop median >=30, dark fraction <=58% in the same fixed region. The W10 reference fails the portrait check.
6. Godot and real SwiftShader Chromium desktop/Pixel gameplay, PCK HTTP206 and Nginx gzip tests are still mandatory before accepting W11.

## Release policy

W11 is not proof of AAA/cinematic quality. The branch is not production. Do not merge unless `OSGARD R135 optimized web candidate` passes and a real portrait image confirms better visibility; reject oversaturated lights, clipped lettering or lost usability. Production deployment requires a separate SHA-pinned artifact promotion and independent public smoke. Physical Android/iOS GPU performance and thermals remain untested.
