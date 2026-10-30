# IRON PULSE WORLD G14 — SOURCE CAPTION CONTINUITY

Date: 2026-10-30. Source stack: G10 tactical atlas, G11 3D contrast, G12 true keyboard/touch, G13 mobile radio/telemetry layout. No international production release is authorized by G14.

## Purpose

The original MARA radio subtitle disappears after its genuine 11–12 second lifetime. Some players cannot comfortably read long authored Russian/English subtitles before the timer ends. The real J/LOG journal retains the entire original story; G14 adds a separately controlled live readability option rather than fabricating new dialogue.

## Actual Godot client

- TIMED (default): preserves original 11–12 seconds. No source game progression differences.
- EXTENDED: a real IPStoryDirector line remains on screen at least 24 seconds; only the presentation timer changes, never the fictional IPCrisisEngine countdown.
- PINNED: the most recent genuinely authored message remains visible after its TTL, until the player changes the presentation mode. It does not generate extra transmissions.
- A real crew/core priority choice always hides radio until the choice is no longer blocking. Pauses, cinematic camera, journal and completed story remain mutually exclusive.
- Actual F4 keyboard input and a 51px CC / F4 button on mobile between PLAN and FAST (no overlap with MAP, VIEW or PAUSE).
- Existing J/LOG stores the complete source dialogue even when the three-line mobile preview uses an ellipsis. RU/EN is provided by the original game story text, not a remote translator.
- A local three-option preference in user://iron_pulse_caption_continuity_g14.cfg is stored without person, device, IP, account or analytics. Existing V6/V9 checkpoint schema is unchanged.

## Source-bound QA

1. scripts/IPCaptionContinuity.gd: deterministic presentation-only safe allowlist and ConfigFile persistence, rejects invalid options and nonfinite durations.
2. scripts/Main.gd: source IPStoryDirector text, real F4/mapped touch, session-independent timer and read-only exact source browser diagnostics.
3. tests/test_g14_caption_continuity.gd: actual Main.tscn import, live story-text equality, pinned/extended/default, RU/EN, local-only privacy, F4/touch, G10 map exclusivity, priority choices and nonmutation of real game decisions.
4. ci/browser_webgl_acceptance.py: exported Godot WebGL receives real F4 inputs and genuine CC touch; original story and game actions are checked without modifying the read-only mirror.
5. ci/world_portal_acceptance.py: RU/EN native caption descriptions, 320/390px responsive design and an accurate disclosure that hardware tests remain pending.
6. Mandatory full V1–V18 and G1–G13 native tests, actual Windows x64/WebGL exports, real Chromium screenshots and G5 secure staging / G6–G9 production HOLD stay in place.

## Open independent acceptance

This is a concrete accessibility feature, not WCAG certification. Real Windows, Android Chrome and iPhone Safari testing is still needed for 30-minute stability, F4 compatibility, audio-caption timing, font fallback, text contrast, long localized lines, mobile landscape and screen-reader behavior. Real users with diverse input/reading needs must review it.

## Remaining large-scale milestones

G15: witnessed original 20-person three-act playtests, real scene capture, difficulty/choice balance, accessibility and independent AAA art/audio quality improvements.

G16: real IP/music/font/trademark rights, privacy/security/age-rating/jurisdiction review, signed Windows artifacts, exact-source delivery provenance, real host canary and exercised rollback, written operator GO.

G17: international post-launch support, voluntary aggregate diagnostics, real backups, incident response and measured RU/EN regional demand. No fabricated users, revenue or worldwide deployment claim.

**Status: DRAFT / OFFLINE STAGING / PRODUCTION HOLD pending independent proof.**
