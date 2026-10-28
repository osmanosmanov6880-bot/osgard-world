# CITY REIGN — Cinematic Operations Garage, native premium UI

**Goal**: make the original playable player's vehicle decisions look like premium AAA game management, not a plain list. Brand system: original R90 charcoal, satin-gold functional headers, monochrome surfaces and visible focus ring. No artwork PNGs or empty decorations.

## Actual running source implementation
- Native `hud.gd` strategy operations keeps four vehicle actions, the same original `_do_vehicle` callback and real `GameState.buy_vehicle` / `GameState.select_vehicle` transactions.
- Each physical owned-game vehicle has a named `CityReignGarageCard_<id>` with accurate catalog title, functional status, price, reputation requirement, live source speed/acceleration/handling bars, fuel-use coefficient and authoritative existing vehicle fuel/health. No fabricated horsepower or random numerical metrics.
- Four native keyboard-focusable minimum-46px action buttons, disabled when ownership/reputation/wallet/selected state disallows action. Never fake a purchase event or charge the player twice.
- Wide viewport: two columns. Compact and actual phone: one column, wrapping labels, no fixed 2-column squeeze. RU/EN/ZH native texts.
- ProgressBar gold design shows 0–1.40 baseline multipliers; adjacent text displays EXACT original catalog coefficient. Users aren't misled into believing a multiplier is a real-world performance measurement.
- No extra SubViewport/secondary 3D pass on phone. The previously accepted LIVE R90 3D city command atlas remains unmodified. This is a legitimate stable-native Godot design, not a mockup.
- The pure source-bound `city_reign_premium_garage.gd` is presentation only; economy belongs exclusively to original `vehicle_catalog.gd` and `GameState`.

## Acceptance
- New original native `v116` checks four cards, desktop/phone column rules, three native languages, source exact stat values, accessible real buttons, genuine purchase with exact treasury debit, and selected state without duplicate debit.
- Previous native v113 art, v115 player-car silhouette and exact SHA full Godot + Chromium WebGL must remain green.
- Four additional QA/AA conditions: real screenshots of actual garage after scrolling in physical browser, measured phone text overflow, keyboard focus order, controller and real-player game session. Not yet human tested. Avoid calling it fully AAA-approved.
- (master), public R87, SSH release, asset rights, commercial royalty clearance, audited hardware FPS: **HOLD**.
