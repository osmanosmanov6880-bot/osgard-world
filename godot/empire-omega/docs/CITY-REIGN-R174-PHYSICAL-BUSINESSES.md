# CITY REIGN R174 — ACTUAL OWNED BUSINESSES PHYSICALLY CHANGE THE ORIGINAL CITY

**Base:** R173 physical street identity \`f68c4511403e12f0c9e12847f407974465be45c7\`.
**Engine:** original Godot 4.4.1/WebGL2; no new save keys; published public R170 unchanged.

## A: Legitimate paid, visually meaningful economic consequence
The original \`GameState.buy_business\` is the ONLY money/debit/ownership authority. The 3 existing business IDs (\`market_stall\`, \`logistics\`, \`workshop\`) are represented by three small original in-scene 3D markers in the actual Market and Freight plaza pedestrian forecourts. Original physical locations, collider and road bounds are preserved. After a paid purchase, the corresponding sign changes native PBR material, local-language owner status and source-catalog base income. Before purchase it remains visibly unowned; never auto-owns or pays the player.

## B: Original local 3D sculptures, not screenshots
Three distinct signed relief objects are made with Godot SurfaceTool — Market solar exchange disc; Logistics linked cargo path; Workshop toothed industrial sprocket. Three original Label3D nodes announce ownership and base income/cost in RU/EN/ZH. Zero new collision/static body, physics raycast, maps, shop prices, remote graphics or external brand media.

## C: Truthful power + GPU limits
Existing \`WorldBuilder.update_development\` is already invoked for \`GameState.state_changed("business")\`; R174 simply syncs its authored real 3D visual there. Existing graphics and 1.1-second spatial culling remove all 6 optional render nodes on LOW, and cull objects outside 112 metres. The ORIGINAL city time/power influences real purchased-metal night emission; a blackout disables it. No per-frame geometry allocation. The new scene is independent of original saved game state.

## Validation / nonclaims
- v171: original business-specific 3D geometry, 750-vertex per-sign budget, physical safe curb bound.
- v172: all three locale/status/sign materials, city power, low-quality/far LOD, economy invariants.
- v173: real full 3D city; actual 500-credit authoritative market purchase; live source \`state_changed\` renders ownership; anti-repeat, city traffic, 34 residents and stored missions unchanged.
- Inherited R173–R169 native Godot, real original SHA-pinned Chromium/WebGL2 tests required before acceptance; production SSH is explicitly not part of this draft workflow.
- Physical Android/iPhone FPS, human session time, art direction signoff, paid-user interest and AAA photorealism are **NOT validated**.
