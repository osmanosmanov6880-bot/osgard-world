# EMPIRE OMEGA R37 - Actual PBR masonry families

R35 supplies real batched facade depth. R37 replaces the single plaster-only
look on existing buildings with three deterministic material families:
mineral plaster, offset-course limestone and staggered brick.

Every material is generated as actual Godot ImageTexture albedo, normal and
roughness maps, using a shared 128x128 tile and triplanar world UVs. Only
3 texture triplets exist for all buildings: at most 589824 RGBA source bytes
before mipmaps and engine copies. District color tints remain preserved.
No network images, license ambiguity or per-building GPU texture allocation.

This does not add new collision geometry or alter R33 wet tyre physics,
camera, economy, missions, saves, accounts or controls. This is not a claim
of photorealistic AAA art. Original game meshes still need expert modeling.

Promotion only after authentic native R35+R37 QA, real 4-viewport Chromium
WebGL pixels, source-fresh Godot WASM/PCK, public SHA-256 7/7 and live
driving evidence. Hardware p95 must be measured on physical phones.
