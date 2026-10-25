# NEBULA R36 — real mobile performance lab and touch diagnostics

## What was missing after R35

The Godot game contained a real 20-second profiler, but on phones its
controls were hidden behind desktop-only **F6/F7/F9** keys. A phone's
reported GPU identity alone is not proof of frame rate, touch latency,
battery endurance or thermal stability.

R36 makes the existing profiler **usable by touch**, with no new cloud
service or silent telemetry collection.

## User workflow (Android Chrome and iOS Safari)

1. Load the live 3D NEBULA world in the browser on the actual phone.
2. Tap the small **FPS** control. The diagnostics panel opens away from
   the nine flight buttons and respects R35 CSS safe-area insets.
3. Tap **20 С**. Fly normally while the 2-second warm-up and 20-second
   real frame-interval sample run. Keep the tab visible. The game itself
   performs the work, using the existing real ship, missions, graphics and
   3D physics. Do not infer frame rates from a screenshot or CI.
4. Read average FPS and p95 frame interval from the report summary.
5. Tap **JSON**. A local JSON file is downloaded **only after this
   explicit user action**. It is not sent to the project, to an ad
   provider or to an analytics endpoint. The full report also contains
   one-percent-low FPS, p99 frame time, device-reported adapter (possibly
   browser-masked), draw calls, quality and sample validity.
6. Repeat in portrait and landscape, then repeat after extended play
   to check whether the measured FPS deteriorates with warming.

The same desktop F6/F7/F9 controls continue to work.

## Touch latency: what is actually measured

R34's production DOM bridge now attaches `performance.now()` to real
touch changes. Godot reads the same browser monotonic clock when it
observes the new touch sequence. It records a nonnegative time difference
and the number of real touch events.

The exported report includes:

- `r36_touch_poll_samples` — touch changes observed during this run
- `r36_browser_dom_to_engine_avg_ms` — mean browser DOM-to-Godot poll delay
  (null when there were no touch events in the sampling window)
- `r36_browser_dom_to_engine_peak_since_launch_ms` — maximum since launch
- `r36_touch_poll_invalid` — out-of-range or unavailable timestamps
- `r36_touch_delay_scope` — explicit interpretation caveat

**This is NOT finger-to-photon, input device sampling delay, GPU frame
latency, network ping or Bluetooth latency.** Do not present these
measurements as any of those metrics. The 20-second frame-interval
benchmark is likewise not a GPU-only timing test.

## Baseline physical-device acceptance matrix

| Device class | Browser | Orientation | Quality profile | Target |
|---|---|---|---|---|
| Recent Android flagship | Chrome | Portrait + landscape | MAX/HIGH | Average ~60 FPS; p95 <= 20 ms |
| Mid-range Android | Chrome | Portrait + landscape | HIGH | Average >= 40 FPS; p95 <= 30 ms |
| Entry Android | Chrome | Portrait + landscape | ECO | Average >= 30 FPS; p95 <= 35 ms |
| Recent iPhone | Safari | Portrait + landscape, real notch | MAX/HIGH | Measure, compare vs same targets |
| Older iPhone | Safari | Portrait + landscape | ECO | Measure; check controls and heat |

These are **targets, not achieved measurements**. The user/devices must
run the benchmark before any physical hardware claim. The Godot program
cannot directly determine battery temperature, case temperature or
operating-system throttling from FPS alone. Monitor symptoms externally;
for rigorous thermal data, use device profiling tools.

Reject a report marked `UNRELIABLE`, including when quality changed
during the controlled sample or long interruption frames were excluded.
Repeat on a visible, focused tab. A report with no touch inputs cannot
support any claim about touch input delay.

## CI contracts

- Native Godot smoke checks the mobile FPS launcher, live panel,
  explicit benchmark activation, viewport safe-area placement,
  desktop isolation and an **explicitly labeled synthetic JSON fixture**.
  That fixture is NEVER a hardware benchmark result.
- Generated HTML JavaScript tests ensure real DOM touch timestamps use
  the monotonic browser clock.
- Chromium real WebAssembly mobile acceptance taps the FPS launcher and
  starts the benchmark through genuine CDP touchscreen events. It does
  not fabricate a physical 20-second Android/iOS result.
- Real Chromium R25 full-world flight and R31–R35 mobile physics remain
  hard CI gates. SwiftShader WebGL frame capture is advisory only.

## Data boundaries

No new fetch, beacon, cookies, session identifiers, payment data or
remote telemetry service. The on-device JSON report contains performance
numbers and generic runtime metadata only. Users decide whether to
share the downloaded file for diagnosis.
