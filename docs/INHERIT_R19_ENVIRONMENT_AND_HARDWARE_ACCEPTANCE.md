# INHERIT R19 — detailed coastline, filmic anti-aliasing and truthful device acceptance

## Actual game changes

The True 3D archipelago now has seven instanced close-range coastal detail groups:

| Visual feature | Efficient mobile | Balanced | High |
|---|---:|---:|---:|
| Wet shore rocks | 32 | 84 | 168 |
| Wind-reactive grass | 96 | 320 | 760 |
| Animated river reeds | 42 | 110 | 245 |
| Iridescent shell fragments | 20 | 72 | 180 |
| Reflective local tide pools | 8 | 18 | 36 |
| Salt-weathered driftwood | 12 | 36 | 75 |
| Wet mineral glints | 24 | 72 | 150 |

High quality renders **1,614** cosmetic instances in **seven bounded InstancedMesh groups**. Seasonal tide, sun, wind and mist change physically based roughness, clearcoat and pool opacity. Existing shared wind shaders bend grass and reeds. Cosmetic scenery never changes the game, save, moves, or generation.

High-tier cinematic postprocessing now includes a proper edge-aware FXAA pass after restrained bloom and before color grading. Backing-pixel resizing is explicit. Low tier and software rasterizers retain fewer passes.

## Measured versus unverified

The existing game has a manual **10-second browser FPS benchmark**. R19 adds a device acceptance tool to interpret its actual measurements. It measures browser frame intervals and CPU submission, plus GPU execution time only when supported by the browser.

**No physical NVIDIA/AMD/Intel GPU or real iPhone/Android device has been tested from this session.** GitHub SwiftShader runs are **software reference tests**, not proof of real GPU performance. Hardware device validation is pending.

## How to validate on real equipment

1. Open the game on your laptop or phone. Select 3D and choose the quality level. Leave motion enabled.
2. Note device, browser, power state, and GPU independently of the benchmark report.
3. Run the built-in button «Тест FPS · 10 с». Copy the resulting JSON using «Копировать отчёт», and save it as device-report.json. No automatic upload occurs.
4. From a copy of the project, run the acceptance script with the target profile:
   - Desktop: node scripts/inherit-device-acceptance.mjs --report device-report.json --profile desktop-30 --out desktop-decision.json
   - Ordinary phone: node scripts/inherit-device-acceptance.mjs --report device-report.json --profile mobile-30 --out mobile-decision.json
   - Entry device: node scripts/inherit-device-acceptance.mjs --report device-report.json --profile entry-24 --out entry-decision.json
5. Repeat after sustained gameplay to detect thermal throttling. Confirm the benchmark did not modify the native save.

## Explicit budgets

| Tier | Average minimum | Observed p95 maximum | CPU submission p95 maximum | Draws / triangles maximum |
|---|---:|---:|---:|---:|
| Desktop high | 28 FPS | 37 ms | 20 ms | 300 / 2.8M |
| Ordinary mobile | 26 FPS | 50 ms | 26 ms | 230 / 1.65M |
| Entry mobile | 20 FPS | 67 ms | 33 ms | 200 / 0.95M |

All tiers constrain the share of frames slower than 50 ms. Missing, interrupted, short or software-rendered results cannot pass the real-hardware acceptance gate. The status observed-pass only means the observed numbers meet a profile: it is not independent proof of the physical GPU.

## Fallback and safety

- Use **2D карта** to restore the original unchanged gameplay view.
- Disable **Киноэффекты** to eliminate high-cost full-screen passes.
- Switch quality to **экономия** to reduce decorative instance counts and pixel ratio.
- WebGL context loss falls back to native 2D gameplay.
- Atlas, generation history, save data, account permissions and placement rules are unchanged by R19.

## Repo verification

The qa:inherit-3d script validates real geometry, bounded groups, season wetness, animated water, local Three.js bundling and prevention of SwiftShader being reported as physical hardware. Browser interaction checks and deployment quality gates still must pass before release.
