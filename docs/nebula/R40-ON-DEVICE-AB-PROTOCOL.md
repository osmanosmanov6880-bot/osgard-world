# NEBULA R40 local on-device A/B testing

## Requirements
- Use the published R38 flight game as baseline, and the PR #342
  `nebula-r40-on-device-candidate` WebAssembly build as candidate.
- Keep one **anonymous device label** for a given physical device across
  both builds, and record orientation/resolution/profile identically.
- For each test batch, choose **R38** or **R40** in the locally running
  R39/R40 report viewer before importing original game JSONs.
- Collect three independent 20-second runs for each of MAX/HIGH/ECO on
  each build. Keep mission/route, charging, thermals and settings stable.
- Viewer shows median FPS/P95 and percent change for matched groups.
  Positive FPS change is better; positive P95 change means lower
  frame time. Any side missing three reliable runs remains incomplete.
- Stable dispersion threshold is currently <=20% of median FPS; noisy
  runs must be repeated.
- +/-5% A/B flags are **descriptive** rather than a formal significance
  test. Do not claim causality, physical device identity or guaranteed 60 FPS
  from these flags alone.
- Keep original JSONs and note visible visual/collision regressions.
  If the optimization causes graphical defects or worse frame-time tails,
  R40 production merge remains blocked.

The viewer does not upload JSONs, phone labels or telemetry to a server.
The test suite uses synthetic fixtures; only field data can approve hardware.

## Привязка к сборке — обязательный контроль R40
Новый кандидат R40 автоматически добавляет в оригинальный JSON
`"build_variant": "NEBULA_R40_BRIDGE_BATCH_3X32"`. В локальной
лаборатории выбирайте «R40» только при загрузке JSON с этой меткой.
Оригинальный R38 не содержит `build_variant`. Несоответствие приводит к
отказу импортировать файл. Старый экспериментальный R40-архив, созданный до
внедрения метки, не подходит: используйте актуальный CI-артефакт PR #342.
Эта проверка защищает от случайного смешения результатов, но метка не
криптографически подписана и не доказывает, какой телефон использовался.
