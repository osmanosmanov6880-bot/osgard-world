# OSGARD R135 W8 — responsive safe-area verification

This is a stacked QA improvement after the W7 stage-rendering PR. Production W5/W6 remains untouched.

## Implemented

- Expose read-only normalized current viewport, `hud_layout_mode`, `hud_rect`, `action_rect` and eight real button centers from Godot UI geometry.
- Within the existing **real Pixel touchscreen gameplay test**, resize the running Godot engine without a page reload through these sizes:
  - 360 x 780 portrait
  - 430 x 932 portrait
  - 932 x 430 landscape
- For each size wait for the Godot scene's live `viewport_w/h` and correct layout mode, assert both status and control panels fully inside viewport (4px edge tolerance), no overlap between status and controls (6px gap), and all eight real button centers inside the control panel.
- Save an actual WebGL screenshot of each layout. Restore the original Pixel viewport and check controls still respond after orientation changes.
- Original W5 diagnostic logic, quality models, score and native physics are unchanged.

## Quality gate

- Native Godot 4.4.1 and Pixel SwiftShader game interaction must remain green.
- W8 viewport QA must reject clipped controls and overlapping panels, not merely check whether buttons exist in the DOM.
- FPS samples in software Chromium are diagnostics only; no physical Android/iOS benchmark is claimed.

## Dependencies

- Stacked on W7 candidate to avoid disturbing W7's in-progress native/web screenshot audit.
- Merge W7 first after its own CI/screenshots are green, then rebase/retarget W8 safely to current master; do not force-overwrite concurrent game changes.
