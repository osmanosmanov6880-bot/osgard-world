# NEBULA R37 — offline performance report comparison

## Completed software component

A real, single-page performance comparison UI is stored at
`public/games/remix/arena-v2/nebula-3d/performance-report.html`.

After production publication, the intended route is:
`https://osgard.world/games/remix/arena-v2/nebula-3d/performance-report.html`.

The viewer uses no network requests, hosted fonts, remote scripts,
cookies, logins or analytics. Selected files are parsed directly in the
current browser tab and disappear after reload. CSV is generated only
when the user explicitly presses the export button.

## Measurement sequence for humans

1. On the actual device, open NEBULA 3D and run the R36 built-in FPS lab.
2. Run **20 С** (2-second warmup + actual 20-second frame sample) in each
   of the three graphics profiles MAX/HIGH/ECO.
3. Download the report with **JSON**. Label report filenames yourself
   with test class and orientation, without including personal identifiers.
4. Repeat for landscape/portrait, and after a sustained 10+ minute flight.
5. Select multiple files in the R37 viewer; compare avg FPS, 1% low,
   p95/p99 frame-time, DOM-to-Godot polling delay and quality targets.
6. Export local CSV for performance discussion; do not paste private
   account information or payment tokens into report filenames.

## Trust boundaries

The report schema is `NEBULA_R12_HARDWARE_BENCHMARK`. The viewer:

- Rejects missing or invalid schema, unknown profiles, NaN/negative values.
- Marks reports as `НЕНАДЁЖНЫЙ` if less than 120 frames, sample not
  approximately 20 seconds, >2 long pauses, quality changed mid-run,
  or the original benchmark marked it unreliable.
- Marks a reported SwiftShader/llvmpipe/software renderer as
  `SOFTWARE GPU`, not proof of Android/iOS hardware speed.
- Compares only credible records to MAX 60 FPS/p95 20ms, HIGH 40/30,
  ECO 30/35, and labels below-target results as areas needing tuning.
- Displays DOM-to-Godot polling delay as **not** input-to-photon latency.
- Uses `textContent` to display filenames and guards the CSV export
  against spreadsheet formula injection.

Device-reported adapter identities may be masked or spoofed, and filenames
are user-provided. The viewer **does not independently attest** that a
report came from physical hardware. Real battery temperature, driver
frame-time counters, iOS safe area and sustained thermal throttle checks
remain separate manual/hardware tasks.

## QA evidence

`scripts/test-nebula-r37-performance-reports.mjs` executes the exact
JavaScript embedded in the deployed HTML using Node.js VM against explicitly
**synthetic** fixtures. It checks valid/invalid flags, thresholds,
software-renderer detection, CSV safety, absence of network upload APIs,
and no unsanitized HTML insertion.

`.github/workflows/nebula-r37-performance-reports.yml` enforces those
checks on PRs and pushes. Passing CI validates report semantics only,
**not** phone FPS, AAA graphics or real device battery/thermal performance.

## Follow-up physical QA

Collect data for at least five device classes: flagship/midrange/entry
Android Chrome, recent/older iOS Safari. Keep both orientations and all
quality presets. Optimize 3D assets/lighting based on actual measured
draw-call, p95/p99 frame-time and thermal regressions, then re-run.
