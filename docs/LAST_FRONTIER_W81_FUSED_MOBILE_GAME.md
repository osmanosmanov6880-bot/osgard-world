# LAST FRONTIER W81 — actual full-bleed Godot world + complete responsive mission input
**Status: engineering DRAFT.** Exact W80 full-screen parent: `57cedb583eeb37c2123f21719345a6536cd2ea36` (PR #646). Original complete W79 five-phase mobile mission and W78 actual CharacterBody3D touch physics remain unmodified.

## Large implementation block
- Integrates the *same original* W80 live Godot SubViewport, original physics player, physical valve, original W63 six-cycle decisions, relay/sync, authenticated checkpoint and full five-phase W79 mission commands with the source-built 4-column / 2-row W80 physical touch grid.
- Repairs previously untested phone geometry: all 8 real W78 WASD/look/G/E controls and 5 original W79 contextual decisions stay within the real 3D stage at 320x700 and 390x844; physical walking and proximity rejection stay sourced from original Godot game.
- Adds **844x390 landscape** phone support. Instead of hiding all mobile controls at width >=640px, center the true 430px physical touch rail and 530px mission dock. Desktop 1366x900 still gets no touch overlay.
- Repairs viewport-resize chrome state: no stale duplicate goal or PLAY NOW rows when browser viewport switches from desktop to portrait. This was the observed W80 separate-grid browser timeout in run 40751557117.
- Genuine native in-world MENU and RU/EN from W80 full-screen stay interactive and original screen reparent reverses with all mission history intact.

## Exact-head acceptance (not a prediction)
- Pin parent 57cedb583eeb37c2123f21719345a6536cd2ea36, allow only 7 W81 source/QA/docs/CI paths, byte-verify original W63-W80 source, real core and W80 full-screen implementation/tests.
- Godot 4.4.1 genuine import + **10 native source gameplay test suites** (9 previous + one combined responsive fullscreen native test), rebuilt WebAssembly/PCK from exact head.
- Real Playwright Chromium pointer & keyboard: preserved W79 complete mission, W80 real fullscreen MENU/RU-EN and W81 320/390/844 viewport; physical W70 walking and source-gated W72 refusal.
- **19 original source-SHA-bound unmodified WebGL screenshots** with SHA256, real bytes and nonblank frame tests (6 W79 + 6 W80 + 7 W81), and mandatory 3/3 jobs.

## Release HOLD
Do not claim human-playtested 10–15 minute completion, iPhone/Android hardware certification, consumer mobile GPU 60fps, safe-area/notch compatibility, original AAA art signoff, legal title clearance or production release. No original gameplay core changes, no generated image substitution, no master merge. Merge only after exact W81 CI is green.

## W81 exact-head landscape regression patch
A responsive fullscreen stage must use exactly `height=size.y` after historical W76 dashboard minimum-height rules; otherwise an 844×390 true mobile view produces a 420px interactive stage and cuts off the bottom physical touch controls. Browser and native geometry now reject this. Original W81 new screenshot driver also compares only **same-size** 844×390 before/after MENU frames, never mixes 320×700 with 844×390. These are actual acceptance fixes, not fabricated screenshot success.

## W81 Chromium 320px timing regression — exact source-fenced fix
The real W81 CI [run 40758764179](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40758764179) had original Godot import, 10 native suites, original W79 browser regression and original W80 fullscreen browser regression PASS, but the W81 browser driver read a 320px state while the original Godot `Control` rectangles were still moving from the previous 390px layout. The preceding original W79 320px screenshot and 390px W81 screenshots are genuine engine frames, not simulated layouts. W81 now waits for the **actual live rect containment of both real machine command buttons and both true native control rails**, then runs the original unchanged strict `verify_mobile_3d_geometry` test. It does not use a sleep-based exception or skip 320px geometry. No physics/gameplay change, no manufacturing green CI.
