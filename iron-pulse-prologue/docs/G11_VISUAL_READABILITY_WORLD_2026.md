# IRON PULSE WORLD G11 — REAL VISUAL READABILITY / ACCESSIBLE SCENE LANGUAGE

Date: 2026-10-30. Base: G10 exact source db89844b2285bbca3a35590c70f054fe373d1589, [full green CI #41044364257](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41044364257). Stacked draft on [PR #700](https://github.com/osmanosmanov6880-bot/osgard-world/pull/700). This work makes actual Godot gameplay more usable; it is not a claim of passing a professional accessibility standard or independent AAA review.

## Real original game code

**New IPVisionProfile.gd** — three reversible modes: STANDARD, HIGH CONTRAST, LARGE TEXT. Render presentation only: no changes to the crisis engine, timer, player position, decisions, story, mission outcome or existing V6/V9 save schema.

**Live control entry points**: F6 on desktop, VIEW / F6 51px button on actual in-game 390/320px layout, Y during the existing pause menu for mapped gamepads, and a visually named 52px pause-menu button. Larger text stays bounded at 1.09x on compact phones and 1.15x at desktop width, avoiding an inaccessible 1:1 desktop scale on 320px devices. High contrast uses darker, more opaque actual Godot panel backgrounds and brighter explicit borders/foregrounds. Every visual cycle is reversible; status is visible through the real native UI and read-only WebGL diagnostic mirror.

**Independent local preference**: ConfigFile in user://iron_pulse_visual_readability_g11.cfg writes only a whitelisted three-value mode and schema marker, never names, email, IP, hardware ID or gameplay checkpoint. Invalid or forged values fail closed to the default appearance. Headless CI does not read or write the player's normal profile, and uses a disposable test fixture.

**Real 3D scene**: G3 IPObsidianArchitecture retains its industrial materials and physically present persistent sector safety signs. Added three Label3D warning signs next to original geometry; status NORMAL/CAUTION/CRITICAL (or Russian text) follows the actual fictional reactor's live heat/oxygen, not random animation. Enhanced outline in contrast/large modes; content survives ECO and reduced motion. Original sector signs, high-energy reactor, geometry placement, collisions, signals and 3D wayfinder are not replaced. No color-only risk or x-ray map/pointer.

## Verification on original gameplay

- tests/test_g11_visual_readability.gd loads the true Main.tscn, checks F6, native pause button, gamepad, mobile button, 3D hazard signs, real source values, RU/EN, 320/390px sizing, local storage allowlist and unchanged event/action count.
- The native CI step runs before expensive Windows/WebGL exports, fails for parsing/runtime/test errors and retains all earlier G1–G10 native acceptance.
- ci/browser_webgl_acceptance.py drives the **actual exported Godot WebGL canvas** via F6 and touches a genuine in-game VIEW button under Chromium mobile emulation. Captures original screen pixels, verifies 3D signs and no fabricated gameplay actions/telemetry. Emulation is not a physical Android/iPhone benchmark.
- ci/world_portal_acceptance.py checks honest RU/EN accessibility copy, no hidden details at 320px/390px, preserved campaign CTA and screenshot provenance, without claiming WCAG certification.
- G5 reproducible source-bound ZIP staging remains read-only; G6 physical, G7 real humans, G8 global legal/security/distribution and G9 real operations remain **RELEASE HOLD** until independently witnessed.

## Control QA checklist

1. Launch the **real** game. With no change from the original game mode, open all three acts, check camera and source gameplay.
2. Press F6. Contrast must visibly strengthen panel borders and three in-world signs, without modifying resource allocation, countdown or movement.
3. Press F6 again. Actual objective, telemetry and interaction font sizes increase; on phone the scale is restrained to keep controls on screen.
4. Press F6 third time. Previous standard style is restored, no stale style override remains.
5. On real desktop, test F6 both from intro and while playing; check language L and native pause buttons; verify the genuine G10 tactical atlas still opens using F2.
6. On physical touch devices, verify VIEW tap area >=44px, reachable in portrait and landscape; check no accidental overlap with MAP, LAB, USE or camera. Browser emulation alone is not sufficient.
7. With real heat >=85 or oxygen <=24 in a consented gameplay test, check 3D warning wording CRITICAL/ОПАСНОСТЬ and color-independence. Return to normal state: words must reset to NORMAL/НОРМА.
8. Check high contrast, larger text, reduced motion and muted audio together under HERO/ECO; inspect at 320,390,768,1366,1920 CSS pixel widths with exact screenshots.
9. Save and restart the app on consenting physical devices; verify only the vision enum persists in a separate local preference file.
10. Test unreadable, malformed and unexpected setting values; default should remain safe and the game must never unlock missions via preferences.

## Independent product review required

The G11 engineering work does not prove all disability needs are met. A separate accessibility and art review should cover screen readers and focus traversal, localized subtitle timings, motor-accessible remapping, color-vision variations, cognitive load, actual Windows/Android/iPhone hardware, contrast calculations on actual rendered screenshots, animation comfort, eye strain and font fallback. Keep named player/reviewer data out of public GitHub. Record actual findings, fix P0/P1 and rerun exact-source tests.

## Large delivery program after G11

- **G12** control customization and accessible subtitles / screen-reader strategy — real game code, not only settings UI; physical-device validation and smoke tests.
- **G13** replay depth, meaningful choices, better authored 3D cinematics, original audio mix, independent visual review and witnessed 20-person three-act study.
- **G14** legitimate worldwide distribution after rights, privacy, signed binaries, real host rehearsal, backups/rollback, jurisdiction review and authenticated production GO.
- **G15** operated multilingual service: real support, consented crash diagnostics, authentic incident response, retention and regional growth only after evidence of reliability and demand.

Never change master, live domains, CDN or commercial settings automatically from G11 CI.

**Release default: ENGINEERING CANDIDATE / PRODUCTION HOLD.**
