# NEBULA R17 — faster WebGL startup without sacrificing PBR quality

## The actual bottleneck

Before R17, `surface_library_r9.gd` and `material_fabric_r12.gd`
synchronously generated seven 384×384 PBR texture sets inside the running
Godot process. Each set contains **albedo, normal, packed AO/roughness/metallic**.
That means **21 texture images / 3,096,576 pixels**, initialized pixel by pixel
on the player's machine during level creation. This can contribute to startup
stalls even when the browser eventually exposes a WebGL canvas.

The source of truth remains the original Godot pixel generator; **R17 bakes
the exact original pixels during CI**, not a cheaper procedural approximation.

## Architecture

1. `tools/bake_r17.gd` runs on native Godot 4.7.2 **before** editor import.
2. It evaluates the original R9 and R12 material routines exactly once.
3. It writes 21 real 384×384 PNG images to `assets/r17_pbr/`.
4. CI checks count, PNG signatures, dimensions and image sizes.
5. Godot editor imports the images. `export_filter="all_resources"` bundles
   these newly generated imported assets into the browser WebAssembly PCK.
6. In the browser, `R9._r17_baked_atlas()` and `R12._r17_prebuilt()` load
   the ready textures. No 384×384 pixel loops are executed there.
7. The original runtime generator **remains available as a fallback** when
   a developer opens an unbaked source checkout.

This changes runtime initialization costs; it **does not** remove materials,
normal maps, roughness/metallicity variation, scene geometry, missions,
physics, account logic, or the R16 guided missile/laser pooling.

## Automated acceptance

- The source checker confirms both loader paths, the headless baker and
  physical-device test instructions.
- The native Godot smoke test requires four R9 + three R12 baked profiles
  to have loaded successfully with all 21 material channels present.
- `NEBULA_R17_PBR_IMPORT_SUCCESS` is printed only after verifying actual
  texture objects and 384×384 dimensions.
- Native Web export and the isolated SSH deployment must succeed.

## Actual browser testing

Open `https://osgard.world/games/remix/arena-v2/nebula-3d/?r17=1`,
then use Ctrl+Shift+R. Compare **cold startup time** after clearing the
site's cache against R16 on the *same* physical computer. F6/F7 and F9
measure actual flight performance; F10 captures the real image. R17 does
not provide independently measured GPU FPS, so no 60 FPS claim is made.

### Chromium QA caveat

The automated hosted Chromium/SwiftShader renderer may fail to capture a
composited image even when the WebGL canvas exists. A 90-second hosted
software-renderer timeout is **not** a real-device frame-rate measurement.
Treat a non-captured software image as `inconclusive`, not a visual success
or proof of a broken client GPU. Retain the exact failure evidence in
the browser QA artifact.

## What R17 does not do

No Stripe configuration, price changes or live charges. Paid goods remain
server-verified; game-credit purchases, story, saves and R16 combat persist.
