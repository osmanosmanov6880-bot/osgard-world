# NEBULA R20 — full-quality offline PBR/weathered deck + neon-glazing startup pass

This is a real modification to the existing Godot WebGL game, not a picture
or a new empty demo. R16 combat/wingmen/missiles, the R15 story and hangar,
and the R17–R19 city optimization and saves remain intact.

## Bottleneck found from actual existing sources

After R17 eliminated **21** 384x384 runtime-generated PBR maps, the player
still generated two more detailed image sets synchronously during _build_city:

- `material_studio_r11.gd`: one full procedural 512x512 set with 3 color,
  tangent-normal and packed AO/roughness/metallic images. Equivalent to
  **786,432 channel pixels** (262,144 texture positions × 3 maps).
- `premium_architecture.gd`: 256x512 day/night glazing atlas with 2 maps
  (albedo + emission), equivalent to **262,144 channel pixels**.

Total **5 images / 1,048,576** image-pixel writes previously performed
on the player's main thread. The source generator is deterministic;
R20 bakes **exactly those original pixels** using the actual Godot methods
during native CI, no lower-resolution substitute.

## Native build and runtime flow

1. R17 builds the original 21 maps as before.
2. New `tools/bake_r20.gd` invokes the original R11 material and premium
   architecture generator on the build runner.
3. Writes `assets/r20_baked/deck_{albedo,normal,orm}.png`
   (3 × 512x512), and
   `assets/r20_baked/facade_{albedo,emission}.png`
   (2 × 256x512).
4. CI checks each PNG binary magic, image dimensions, expected names
   and that all five assets are nontrivial.
5. Native Godot editor imports all assets, the Web export includes them in
   the production PCK.
6. At play time the material classes use ResourceLoader for original
   prepared images rather than executing their long pixel loops.
7. Original generators are still available as an automatic fallback when
   opening a developer checkout without the baked textures.

Exact color, normal, roughness, metal and window emission settings are
preserved. Tests assert actual PCK-loading success and image dimensions.

## Acceptance and honest performance claims

- Native 4.7.2 import, gameplay scene, all previous runtime smoke assertions.
- New tests require the loaded R11 metal (512x512) and facade (256x512)
  textures in real materials, not just files in repository.
- WebAssembly export, squash merge, main-branch rebuild, isolated SSH
  activation and Nginx are independently verified.
- Browser capture from hosted SwiftShader has historically failed at
  1280x720 despite the canvas existing; this is **inconclusive** about
  the player's GPU.

Physical test: open
`https://osgard.world/games/remix/arena-v2/nebula-3d/?r20=1`
and hard reload with Ctrl+Shift+R. Compare both the **cold loading time**
and FPS on the same GPU and browser before and after R20. Use F6/F7/F9 for
a 20-second real frame-time sample, and F10 for a real image.

Reducing main-thread texture baking should reduce initialization work.
It **does not prove** any particular GPU FPS, loading time, or AAA photorealism.

**Stripe is unchanged**, and real payments remain separately gated.
