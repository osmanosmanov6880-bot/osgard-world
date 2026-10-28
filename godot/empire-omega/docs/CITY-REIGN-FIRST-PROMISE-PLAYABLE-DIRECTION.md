# CITY REIGN — EPISODE 01: THE FIRST PROMISE / AUTHENTIC CITY CINEMATIC ROADMAP

## Purpose
One genuinely connected street-level story: arrive at the car, deliver the first market order, earn operating capital, choose city spending through the authentic governance interaction, physically visit the funded site and see its REAL completed structure.

## Source of truth
- The first 40 campaign mission IDs and rewards are defined only in `mission_manager.gd`.
- Economy, save progress, investments and turn consequences are defined only in `game_state.gd` and `civic_initiatives.gd`.
- `city_reign_first_promise.gd` derives branching episode phase from actual mission/project state.
- `city_reign_promise_markers.gd` owns the original two on-foot civic choice signboards.
- `project_landmarks.gd` already shows the real funded/under-construction/completed civic monument.
- New `city_reign_opening_director.gd` produces **read-only street navigation** with a compact physically modeled 3D gate and short RU/EN/ZH objective caption, and hides itself when irrelevant. No picture, fabricated project, reward, fixed timeline or FOV camera intervention.

## Story beats and factual current status
1. **Arrival:** actual parked car source position on city street, authentic enter-vehicle mission, optional read-only physical cue. Implementation candidate.
2. **Market Drive:** source actual citymarket destination at (130,-130), authentic 3D traffic and delivery trigger. Implementation candidate.
3. **Capital and Decision:** company/turn are governance-menu actions, no fake courier route. Two real public-investment choices already cost resources/materials. Implementation exists; new guide merely highlights an existing board.
4. **In Progress:** original 2 or 3 real economic turns, real existing animated scaffold and no duplicate expenditure. Implementation exists, new same-state wayfinding.
5. **Delivered:** original saved `projects_done` summons the built physical city asset with economic effects, resident reactions and remaining free-city gameplay. Implementation candidate.

## Candid artistic limits
This is a readable new narrative/wayfinding link, not a finished 30-minute screenplay, AAA acting/cutscenes, professional voiceover, human-controlled animation rig or directed cinematic trailer. Independent human UX/hardware FPS and art-signoff still missing. It is important to avoid gratuitous roadside giant UI, copyrighted asset imagery and detached screenshot cutscenes.

## Acceptance without fake victories
Original Godot v121 must load the genuine playable scene, perform real city payment `start_initiative('open_records')`, advance TWO real turns, verify completed original 3D public archive, inspect 12 original car NPCs/34 residents, check original mission unchanged and no extra saved keys. All native CI, original full-city WebGL and manual release contract must be green before R90 candidate merge. Master/public deployment HOLD.

## Source-original City/Chromium screenshot gate
The disposable CI `tests/city_reign_opening_live_pixel_fixture.gd` uses the actual `WorldBuilder.gd`, `project_landmarks.gd`, `city_reign_promise_markers.gd`, `city_reign_opening_director.gd` and original registered `GameState.start_initiative('open_records')`, plus TWO real `advance_turn()` calls. A real Godot 4.4.1 WebGL export on localhost captures the original City Hall-adjacent proposal site before financing, funded scaffolds, partially advanced works, the physical public archive completed after two turns, and LOW mode which hides only new guidance. Each change must occur in real captured pixel deltas; failures are not hidden, thresholds are NOT reduced for convenience.

This source-only fixture is NOT a claim of cinematic AAA actor rendering. Production entrypoint remains `res://scenes/main.tscn` on all Git commits; CI swaps to the optical test scene only inside disposable checkout. All screenshots and source SHA are published as GitHub Actions proof.
