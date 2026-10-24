# R135 W10.1 — fix first-frame portrait status panel

## Why W10 archive did NOT ship
Source `f2a919ea0e948073ad87ff8281980f87041dd997` passed native Godot, actual Chromium and three viewport resize tests, then was merged into `master` as PR #329. During **human inspection of the actual CI `w6-portrait-optical-active.png`**, the initial mobile viewport displayed a nearly full-height semi-transparent status panel that darkened the 3D machine. The same game rendered correctly **after** one viewport resize. Therefore the W10 archive from run `40114198950` is rejected for public promotion despite successful CI.

## Root cause and implemented correction
`StandaloneMain._update_layout()` called `PanelContainer.reset_size()` on the **first** layout pass when the status-label and control grid geometry had not been settled. The initial computed height could occupy most of the screen. In W8 resizing did need `reset_size()` to discard the original width after a DPR/orientation change.

W10.1 now:
1. Uses original W7 normal container sizing on startup (and on redundant same-size notifications).
2. Uses forced `reset_size()` **only when the root visible viewport has actually changed** after startup; retains the proven W8 narrow-screen and orientation behavior.
3. Adds a mobile browser assertion during **boot** and while viewing the active optical fault. The status panel must occupy no more than 28% of viewport height and must not overlap the operator touch panel, leaving a real playable scene area.
4. Retains the real 360×780 / 430×932 / 932×430 safe area QA matrix, W9 clues, safety interlocks, all 8 touch controls, HERO/ECO originals and W10 SHA-256/ZIP checks.

## Release acceptance
- Godot 4.4.1 native and Chromium gameplay CI must be green on the W10.1 **source commit**, not only on original W10.
- Independently inspect `w6-portrait-optical-active.png` from the W10.1 run: no full-height HUD overlay, optical head/caption legible.
- Validate the exact new package manifest SHA-256, not previous W10's `c22a85a...` or published W6's SHA.
- Only after those checks, use a separate protected release promotion PR and public-byte audit.
- Physical phone FPS/thermals and cinematic AAA art remain unverified; test does not imply hardware quality.
