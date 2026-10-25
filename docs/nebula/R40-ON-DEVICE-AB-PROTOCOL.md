# NEBULA R40 local on-device A/B testing

## Requirements
- Use the **approved R38 production baseline** at
  `https://osgard.world/games/remix/arena-v2/nebula-3d/`.
- Use **only the isolated R40 QA source** at
  `https://osgard.world/games/remix/nebula-r40-qa/`.
  The source is [PR #375](https://github.com/osmanosmanov6880-bot/osgard-world/pull/375)
  head `9efb03c246a28a168886e2aa494872e907ea78cd`,
  original successful CI run `40173218842`. This is not production approval.
  Both URLs must serve the four reference files with correct pinned bytes
  before hardware collection; do not use old candidate pull requests.
- Keep one **anonymous device label** for a given physical device across
  both builds, and record orientation/resolution/profile identically.
- For each test batch, choose **R38** or **R40** in the locally running
  R39/R40 report viewer before importing original game JSONs.
- Use **two real Android phones** (different performance classes) and **one
  physical iPhone Safari**, portrait and landscape, manually selected
  MAX/HIGH/ECO and three independent 20-second samples on both R38 and R40.
  This is exactly **3 devices × 2 orientations × 3 profiles × 2 variants ×
  3 samples = 108 original JSON reports**, plus **12 original screenshots**
  (each device × both orientations × both builds).
  Keep mission/route, charging, thermals and settings stable.
- On each actual phone, tap `FPS` → `20 С`, fly for the 2-second warmup
  and 20-second sample, then tap `JSON` to explicitly download the real
  `NEBULA_R12_HARDWARE_BENCHMARK` result. The export uses the historical
  filename `nebula-r36-real-device-performance.json` on both versions;
  keep every downloaded file's bytes unchanged, even when naming repeated
  files for private storage. Do not mistake starting a benchmark for a
  completed, trustworthy 20-second result.
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
внедрения метки, не подходит: используйте оригинальный CI-артефакт
PR #375 (run `40173218842`), опубликованный только по изолированному
QA-маршруту. Сверка источника задаётся в
`.github/nebula-r40-qa-one-shot-source.json` и
`.github/nebula-r40-qa-ci-artifact-pin.json`.
Эта проверка защищает от случайного смешения результатов, но метка не
криптографически подписана и не доказывает, какой телефон использовался.

## Frame-pacing release check (2026-10-25)
The offline field-gate also compares **median 1% Low FPS** and **median P99
frame-time** across actual same-device runs. It rejects the R40 candidate if
1% Low drops by more than 5% or P99 frame time increases by more than 5%,
even when average FPS improves. These are pragmatic regression thresholds,
not a statistical confidence interval; unstable/thermal-affected samples still
require human review and retesting.

## Глобальная уникальность источников аппаратной приёмки
Вся матрица 108+ измерений дополнительно проверяется на повторное использование
оригинальных файлов: совпадение SHA-256 любого JSON либо скриншота между
разными устройствами, ориентациями, версиями или профилями останавливает
приёмку. Также запрещено повторное время исходного замера у одного телефона
и одной версии игры, даже если данные были переписаны в новый файл. Эта
проверка защищает от случайных повторных загрузок, но **не** удостоверяет
честность полевого тестировщика и не заменяет личный осмотр устройства.

## Неизменяемый источник и честные границы результатов
- Разрешённая production-версия — **R38**; текущий R40 — **только QA**.
- Оригинальный CI ZIP R40 имеет SHA-256
  `7bc3fb85b7f01917193cde544ee976bf835757fbdfdff9d03cd98dadc3c2d02d`.
  Эталон `index.wasm`:
  `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`.
  Эталон `index.pck`:
  `14b77651ea241ba6d8f19f05a4991a5361234c2e82e99f3624d8994112c0eebd`.
- Отчёты/скриншоты хранятся **локально**, без автоматической отправки.
  Отсутствующий файл, дубликат, программный GPU, неправильная метка сборки,
  незавершённый профиль или некорректное время делают слот недействительным.
- Браузерный CI и SwiftShader проверяют доступность интерфейса, но не
  удостоверяют FPS и температуру физических Android/iPhone. Для production
  требуется независимый инженерный осмотр оригинальных 108 JSON, 12
  изображений, условий измерений и отдельное решение о выпуске и откате R38.
