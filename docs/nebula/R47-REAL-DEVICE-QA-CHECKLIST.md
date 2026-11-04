# NEBULA — real-device QA checklist (R47 onward)

**Status: TEST PLAN ONLY.** No physical device, screen recording, GPU measurement or human sign-off is attached. This document cannot certify hardware QA for R40, R47 or any release.

## Devices and browsers

Test at minimum one modern Android (Chrome, GPU acceleration), one entry-level/mid-range Android (Chrome), and one current iPhone (Safari WebGL). Record exact device model, OS/browser build, screen size, GPU, available RAM, date, network condition and source build SHA. Do not write identifying account credentials in logs.

## Repeatable runs (collect raw evidence)

1. Cold HTTPS start and initial garage readiness: record first visible 3D frame, interactive time and real WebGL errors; verify 4-file public SHA identity before testing.
2. In portrait, landscape and compact portrait (including actual notch/safe area), rotate docked NX-08/NX-12/NX-21. Confirm all ship controls reachable, readable and not obscured.
3. Verify empty R47 3D pads. Obtain ESCORT and ACE only by legitimate owned CR state or real authenticated server proof. Select/deselect each and verify real 3D occupancy, flight ally behavior and save after reload. A forged browser signal must never grant entitlements.
4. Launch first mission from actual on-screen button. Ensure immediate craft movement, short FOV reveal without an input lock, normal sound, no dangerous frame jumps, no forced combat in the garage.
5. Shoot and survive with both wingmen; assert they do **not** fire from garage. Invalidate a paid entitlement server-side and check revocation removes that helper from live formation and visual pads.
6. Let craft genuinely crash; inspect explicit failure, return to garage, complete repair and retry the exact mission. Confirm no duplicated rewards, no lost purchases, and no stuck touch after release.
7. Fly at least 30 minutes under normal conditions, including screen rotation and browser tab hide/show. Capture 1% low FPS, sustained FPS, memory changes, GPU errors, thermals, excessive battery drain, and any reloads.
8. Repeat with offline/slow connection, page refresh, expired login and rejected payment callbacks. Payments cannot unlock helpers from a return URL alone.

## Target quality gates — not measured results

- Input interaction and steering must remain responsive; no stuck touch controls after orientation changes.
- Aim for >=30 sustained FPS on supported mid-range devices and >=50 FPS on high-end devices in ordinary missions, with the actual 1% lows recorded; these are goals, **not achieved claims**.
- No hard crash or loss of owned progress in a 30-minute session.
- Users should understand garage, owned units, mission objective and return path without tutorial instructions.
- Manual reviewer must compare screenshot/video to product visual guidelines for contrast, HUD readability and acceptable visual degradation under ECO settings.

## Sign-off requirements

Attach raw per-device run logs (with timestamps), screen recordings/screenshot hashes, source Web export identity and reviewer decision. Distinguish emulated Chromium touch QA from real physical devices. No fabricated, inferred or synthetically padded reports are acceptable. The GitHub owner-directed override remains explicitly `physical_device_qa=NOT_PERFORMED` until the complete separate real-hardware review is performed.
