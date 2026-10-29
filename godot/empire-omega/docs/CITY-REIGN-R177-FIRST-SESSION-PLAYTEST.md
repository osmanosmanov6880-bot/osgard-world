# CITY REIGN R177 — FIRST SIX PLAYTEST OBSERVABILITY

**Base:** R176 source game; public server remains on independently verified R170 until a separate deploy with signoff.

## Engineering 1 — measure actual first six actions, never guess timing
\`city_reign_first_session_observer.gd\` is a small capped native, in-memory, original-main-scene observer of the ACTUAL \`GameState.mission\` source index and elapsed **foreground, unblocked gameplay frame time**. No new mission ledger or rewards. Records up to 12 real stage-transition records for 6 original episode actions. Restored saves starting at stage>0 remain partial and cannot count as a full first-six run. Stage jumps are marked incomplete; resetting a save clears observation. It explicitly **never** claims that passing simulation tests proves a real human took 5–10 minutes. The 5–10-minute hypothesis is assessed only after all six contiguous source stages occur in a single freshly started instance.

## Engineering 2 — local, opt-in proof
The EXISTING built-in diagnostics panel gets ONE scrollable, unobtrusive local session status + manual JSON export button, reusing the standard UI style. \`Main\` connects its existing panel and records at the original frame update with no extra background timers, network, cookies, user ID or analytics vendor. Export happens only after user clicks and saves locally via built-in native user:// or Web browser download. No sensitive addresses, camera footage, input history, device identity or location are recorded. The exported data says \`full_human_playtest_attested=false\` until independently verified; it is not an attestation or proof of usability.

## Engineering 3 — old games and accessibility
No changes to the original player/vehicle, economy, save version, 40 missions, original audio, HUD overlays, city PBR or mobile controls. The debug panel scrolls on compact layouts instead of blocking the playable city. Menu and background intervals are excluded from **active gameplay seconds** by design and labelled as such. Invalid long/NaN frames are rejected and counted. A bound of 7,200 active seconds and 12 records prevents run-away memory. In-game source load/reset triggers an honest fresh measurement.

## Independent native and real browser QA gate
- \`v180\` exactly six original adjacent source transitions over 360 seconds, verified timing, no source money/save writes
- \`v181\` resumed stages, skips, backgrounds, menu time, long frames, caps, reset and honest unverified status
- \`v182\` actual native full original 3D Godot scene, HUD export controls and 12 cars/34 citizens unchanged
- Inherit all R176–R169 native regression, real exported WebGL2, 3 native camera/car Chromium tests and independent exact-SHA browser acceptance. No SSH release.
- **HOLD** pending uncoached human session, physical Android/iOS FPS and commercial visual-art approval.
