# ZION-030 v30 - HIGH-DETAIL ASSET SYSTEM

This release is a real code change for the existing WebGL/Three.js open-world mode. It is not a still image, an Unreal Engine build or an AAA-photorealistic production asset pack.

## Design intent

- Streets remain fully playable on the authoritative ZION-030 mission/physics grid. The original three-zone puzzle, multi-stage dispatch contracts, and local saves are not replaced.
- High-fidelity-looking geometry should be **legible from the player's shoulder**, not only from the old overhead map.
- Instanced details use a shared cube/sphere/cylinder primitive and shared materials rather than separate mesh draw calls.
- Expensive geometry is never generated on software WebGL or reduced-motion devices. Mobile receives a dedicated medium tier and desktops with hardware rendering receive the ultra tier.

## Shipped detail families

1. **Architecture:** real inset-looking window panels with varied warm/cold lighting, mullions, lintels, stone sills, cornices, balcony slabs and railings, front doors, illuminated shop awnings, roof trim, HVAC units, satellite masts, rooftop solar equipment and gutters.
2. **Road engineering:** procedural 512x512 asphalt surface with seeded grain/cracks, painted lane guides, crosswalk markings, curb stones, storm drains, pavement seams and utility housings.
3. **Environmental props:** multiple tree canopy silhouettes, trunks, extra shrub clusters, planter stones, shelter roofs, columns, charging pedestals with LED status elements and street furniture.
4. **City Runner EV:** bumper intake, trim, headlights/taillights, detailed rims, windshields, mirrors, doors and badges. Assets are attached to *the actual player/traffic vehicle meshes*.
5. **Playable character:** clothing seams, shoulder straps, bag labels and footwear details attached to the *animated player object*.

## Measured geometry budgets (deterministic scene-graph test)

| Tier | Windows | Decor instances | Geometry draw-call groups | Car parts per vehicle |
|---|---:|---:|---:|---:|
| Hardware desktop / ULTRA | 6,010 | 34,471 | 25 | 39 |
| Mobile / MOBILE | 2,920 | 10,763 | 13 | 29 |
| Software WebGL or reduced motion / LITE | 1,376 | 5,729 | 13 | 7 |

These numbers are construction counts, **not FPS or production GPU benchmark results**. On the desktop, the detailed facade/road environment is assembled into 25 draw-call batches instead of issuing thousands of mesh calls. Road-texture generation is skipped on low-tier devices. The quality toggle hides/restores the optional high-detail layer rather than rebuilding geometry each frame.

## Quality gates

- Unit scene-graph test validates finite transforms, batches, asset counts, independent quality tiers and vehicle/avatar attachment.
- Full JavaScript source parsing and original v26-v29 gameplay regression remain mandatory.
- Playwright must render the actual browser version on desktop and phone, verify asset stats, quality toggle, original scene exit and absence of unhandled errors.
- Do not publish if required frontend/browser workflows fail. Production activation requires a successful SSH workflow and byte-identical file verification.

## Planned next work

For true photorealistic visuals, substitute scanned or artist-authored PBR materials, bespoke high-poly buildings, skeletal animation, photogrammetry props, baked lightmaps and mesh LODs from a proper DCC pipeline. Consider Godot 4 / Unreal native edition *after* the browser vertical slice is proven fun and performant. No Unreal export is claimed here.