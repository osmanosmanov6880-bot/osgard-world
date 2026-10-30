# IRON PULSE WORLD G13 — REAL MOBILE HUD / SOURCE-BOUND GAMEPLAY

**Baseline:** Stacked on G12 feature branch; original three-act Godot client preserved. No changes to master, live websites, staging activation, source saves or commercial production.

## Block A — redesign the ACTUAL Godot interface

This release repairs a concrete visual defect: on compact native WebGL canvases the MARA operator radio and live reactor telemetry overlapped each other and sometimes obstructed touch controls.

- **390 × 844**: original Godot header finishes near CSS y=115. Live telemetry occupies y=130–240, and MARA's original story card occupies an independent region beginning at y=248 and finishing before the first touch row near y=373. The automated acceptance checks the actual Godot Control.get_global_rect, never a fabricated CSS mock.
- **320 × 720**: height is too constrained for both large cards. While a timed MARA dialogue or crew/core priority decision is visible, the large telemetry card temporarily yields, but real heat, oxygen and time remain on a compact source-derived footer. Full narrative is still in the native journal. When radio expires, original full telemetry automatically returns. Crew/core selection takes precedence over transient radio.
- The actual HUD adjusts source-font sizes and physical panel regions. Touch buttons remain native 51px. All current source game metrics continue to be updated by IPCrisisEngine.
- RU/EN, three-act story, save formats, real G10 Tactical Atlas, G11 vision and G12 keyboard accessibility continue unchanged.
- Read-only g13_mobile_hud exposes original Godot panel rectangles, current authentic layout, whether the emergency footer is sourced from real engine data, and the explicit absence of server telemetry.

## Block B — exact-source native and browser verification

1. tests/test_g13_mobile_hud_reflow.gd instantiates the original Main.tscn and tests 390px and 320px mobile panel geometry, source-derived numerical indicators, genuine opening MARA transmission, language, crew/core choice layout, natural radio timeout restoration, original desktop presentation and unchanged engine choices.
2. ci/browser_webgl_acceptance.py runs Chromium against the actual exported Godot WebGL game at desktop and 390px; checks real HUD rectangles while the authentic authored first radio is visible and captures genuine game frames rather than generated substitutes.
3. ci/mobile_hud_320_acceptance_g13.py independently launches the original **320×720** export, proves true on-canvas RU/EN tap, captures real screenshots during the radio story and after it expires naturally, checks visibility and actual touch geometry, and disallows fake game state injection.
4. ci/world_portal_acceptance.py verifies bilingual honest product copy at desktop, 320px and 390px CSS widths. Visuals remain actual game source.
5. Prior V1–V18 and G1–G12 tests, Windows x64/WebGL exports, G5 real archive/rollback and G6–G9 strict release-hold gates remain compulsory.

## Source trust, privacy, and honest limitations

Every gameplay metric is from the current Godot session. Tests deliberately do not modify engine state and do not fabricate players, achievements, personal identifiers, network requests or physical devices. Original saves and actual gameplay physics stay untouched.

G13 is software engineering, NOT independent AAA artistry, WCAG certification, physical iPhone Safari or Android/Windows GPU certification, complete licensing, real-host staging, production support, business traction or commercial approval. No master merge, live domain deployment, CDN, signing or automatic publication is performed.

The exact-head GitHub Actions full workflow is the technical acceptance requirement. PR stays **DRAFT / RELEASE HOLD** until all evidence is independently accepted.

## Large roadmap to global operations

**G14 — physical devices and accessibility:** real Windows integrated/discrete, Android low/mid, iPhone Safari; portrait/landscape input and visibility; measured GPU, memory and thermal/30-minute soak, controller remapping, accessible subtitles and color-independent risk signs.

**G15 — players and independent AAA quality:** recruit 20 actual consenting players completing the three-act campaign, record genuine failures, evaluate replay, onboarding, cinematography, music, narrative and accessibility, fix and retest every P0/P1 and independent art/sound review.

**G16 — legal worldwide launch and operation:** verify asset/music/fonts/IP rights and store age ratings; real Windows signing, trusted downloads, privacy/security audit, real staging, backup/rollback and accountable human GO. After launch, support RU/EN, practice real incidents, measure opt-in 30/60/90-day adoption, retention, crashes and unit economics before adding languages and regions.

**Commercial production remains HOLD until external witnesses, real players and licensed infrastructure complete independent acceptance.**
