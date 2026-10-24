# NEBULA R39 — actual-device measurement campaign (field kit)

## Status boundary
The software implements local comparison and run-repeatability acceptance.
A Chromium/SwiftShader CI pass **does not** count as a physical-device result.
Do not mark R39 hardware testing complete without exported original reports
from actual Android and iOS devices. No remote collection or analytics.

## Operator procedure (per physical phone)
1. Record an anonymous, locally chosen device label, operating system/browser,
   approximate refresh rate, battery saver status and test date outside the JSON.
   Do not collect personal identifiers, precise serial numbers or contact details.
2. Load the **published** NEBULA build, ensure flight controls function and
   choose a fixed MAX/HIGH/ECO profile (not AUTO). Keep the browser foregrounded.
3. Fly the same repeatable route across the port and city; record one full
   2-second warmup + 20-second run. Use the explicit JSON download.
4. Repeat **three independent runs** for each fixed profile without changing
   screen orientation, in portrait AND landscape. Avoid charging or thermal
   changes mid-group when possible; note them if unavoidable.
5. Before importing, enter the same anonymous device label in the R39
   browser-only analysis field. Import reports for that device as a batch.
   Use a distinct label for each different physical phone.
6. Inspect median FPS, median P95, FPS spread, slow-frame tail (P99, 1% low),
   and DOM->Godot dispatch. The latter is **not** input-to-photon latency.
7. Retest any group with fewer than 3 valid samples, software GPU detection,
   missing resolution, profiler profile drift, pauses, or >20% FPS spread.

## Acceptance logic (conservative)
- Grouping key: anonymous device label + reported resolution + fixed profile.
- Only reliable reports from non-software renderers with a valid original
  `date_unix` field are eligible for median. Exact repeated timestamps within
  the same device/viewport/profile group are treated as duplicate JSON,
  counted separately but NOT treated as independent trials.
- Timestamps alone cannot attest phone identity or prevent a deliberately
  forged report; this guards accidental duplicate uploads, not fraud.
- >=3 eligible reports per group. FPS spread = (max - min) / median x 100.
- If FPS spread >20%, mark UNSTABLE, even when median FPS is high.
- Median targets from the existing R36/R37 definitions:
  MAX >=60 FPS with P95 <=20 ms; HIGH >=40 FPS with P95 <=30 ms;
  ECO >=30 FPS with P95 <=35 ms.
- More than 3 valid samples are allowed. A passing metric isn't proof of
  specific phone/GPU identity, thermal stability or AAA graphics.

## To complete R39 and start R40
Provide real original JSON datasets for several distinct Android models and
at least one iPhone Safari device, including one low-performance Android.
The physical test operator must verify controller hit areas, scene appearance,
rotation and thermal issues alongside the reports. The QA engineer must
preserve before/after data for the **same device, profile, route and orientation**
before claiming that R40 optimizations improve performance.

## Privacy / interpretation
Viewer is self-contained, offline-capable and performs no uploads.
Manual device labels are included in exported CSV only by an explicit click.
Its summary and CI synthetic fixtures assess repeatability math, **not**
whether anyone actually tested a physical device.
