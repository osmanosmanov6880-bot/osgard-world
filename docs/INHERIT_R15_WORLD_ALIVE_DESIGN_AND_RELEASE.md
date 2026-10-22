# INHERIT R15 — WORLD ALIVE

## Design and release contract

This implementation upgrades the existing browser game without changing its ownership model, generation persistence, player budget, payment status, or server API. It does not claim to be Unreal Engine photorealism. The game still uses the original HTML/CSS/JS 2.5D world.

### R14 foundations incorporated

- Original illustrated sprites for all ten true trace types
- Brighter, layered island terrain, lighting, foliage and water
- Clear three-step first interaction, large controls and mobile layout
- Source-preserving action rail, true atlas and native chronicle
- Font enlargement, RU/EN/ZH and reduced-motion support

### R15 gameplay elevation

- **World Alive Engine:** pure model derived from InheritStoryEngine, InheritWorldCycle and InheritLegacyEngine. Chapter objectives, link counts, island stage and fictional season all use the existing saved world.
- **Mission command center:** the three real chapter goals are accessible directly in the main game; "Choose" triggers a real existing tool. The player must independently click the island to spend the actual budget.
- **Responsive environmental storytelling:** fictional tide, sun, wind and mist correspond deterministically to the currently saved generation. No actual weather claims are made.
- **Verified action feedback:** burst and optional sine-wave sound trigger only after a normal game click adds exactly one object and decreases real budget by one. No synthetic places, fake boosts or new currencies.
- **Generation transition:** cinematic light flash and text are shown only when the original saved generation increases following a pending handoff.
- **Performance:** 2D water canvas capped at 1.5x device pixel ratio and approximately 20 frames/second, paused offscreen, in low-power mode, reduced motion and hidden tabs.
- **Audio privacy:** disabled by default, opt-in through a user gesture, synthesized locally and without network requests.
- **Honest access:** commands are disabled for read-only/invalid worlds and restricted account state.

### Validation

- `npm run qa:inherit-living` and `npm run qa:inherit-world-alive`
- Existing INHERIT save, Atlas, story, Legacy, account and offline regressions
- Chromium desktop/mobile tests for chapter progress, permissions and standard game flows
- Mandatory SSH release gate compares SHA-256 of exact public HTML, CSS, JavaScript and SVG files
- R15 PWA cache: `inherit-shell-v27`

### Shipping

1. All source checks and desktop/mobile browser tests pass.
2. Merge into `master`.
3. Standard SSH workflow deploys the candidate.
4. Post-SSH byte-level asset checks pass against `osgard.world/games/inherit/`.
5. Confirm public gameplay and fallback/rollback.

**Never describe an open PR or a passing source test as a published game.**
